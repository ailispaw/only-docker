BOX_PACKER  := only-docker-box
HDD_BUILDER := only-docker-hdd
ISO_BUILDER := only-docker-iso
BOX_TESTER  := only-docker-test

BOX_NAME := only-docker.box
HDD_NAME := only-docker.vdi
ISO_NAME := only-docker.iso

VAGRANT := vagrant
VBOXMNG := VBoxManage

KERNEL_VERSION   := 3.18.7
DOCKER_VERSION   := 1.5.0
BUSYBOX_VERSION  := 1.23.1
DROPBEAR_VERSION := 2015.67

box: $(BOX_NAME)

hdd: $(HDD_NAME)

iso: $(ISO_NAME)

install: $(BOX_NAME)
	$(VAGRANT) box add -f only-docker $(BOX_NAME)

$(BOX_NAME): $(ISO_NAME) $(HDD_NAME) box/vagrantfile.tpl box/busybox_plugin.rb
	-$(VBOXMNG) unregistervm $(BOX_PACKER) --delete
	#
	# Detach HDD
	#
	-$(VAGRANT) halt $(HDD_BUILDER)
	-$(VBOXMNG) storageattach $(HDD_BUILDER) --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium none
	-$(VBOXMNG) closemedium disk $(HDD_NAME)
	#
	# Create VM
	#
	$(VBOXMNG) createvm --name $(BOX_PACKER) --register
	$(VBOXMNG) modifyvm $(BOX_PACKER) --ostype Linux26_64 --memory 512 --ioapic on
	$(VBOXMNG) modifyvm $(BOX_PACKER) --boot1 dvd --boot2 disk --boot3 none --boot4 none
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nic1 nat --nictype1 virtio --pae off
	for i in 2 3 4 5 6 7 8; do $(VBOXMNG) modifyvm $(BOX_PACKER) --nictype$${i} virtio; done
	$(VBOXMNG) storagectl $(BOX_PACKER) --name "SATA Controller" --add sata --portcount 4
	#
	# Attach HDD
	#
	$(VBOXMNG) storageattach $(BOX_PACKER) --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium $(HDD_NAME)
	#
	# Package Box
	#
	$(RM) only-docker.box
	cd box && $(VAGRANT) package --base $(BOX_PACKER) --output ../$(BOX_NAME) \
		--include ../$(ISO_NAME),busybox_plugin.rb --vagrantfile vagrantfile.tpl
	#
	# Detach HDD
	#
	$(VBOXMNG) storageattach $(BOX_PACKER) --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium none
	$(VBOXMNG) closemedium disk $(HDD_NAME)
	#
	# Cleanup
	#
	$(VBOXMNG) unregistervm $(BOX_PACKER) --delete

$(HDD_NAME):
	$(VAGRANT) destroy -f $(HDD_BUILDER)
	$(RM) $(HDD_NAME)
	#
	# Create HDD
	#
	$(VAGRANT) up $(HDD_BUILDER) --no-provision
	$(VAGRANT) provision $(HDD_BUILDER)
	#
	# Detach HDD
	#
	$(VAGRANT) halt $(HDD_BUILDER)
	$(VBOXMNG) storageattach $(HDD_BUILDER) --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium none
	$(VBOXMNG) closemedium disk $(HDD_NAME)
	$(VAGRANT) destroy -f $(HDD_BUILDER)

$(ISO_NAME): iso/Dockerfile iso/assets/motd iso/assets/profile \
		iso/assets/console-container.sh iso/assets/init iso/assets/isolinux.cfg \
		iso/assets/kernel_config iso/assets/os-release \
		iso/linux-$(KERNEL_VERSION).tar.xz iso/iptables-1.4.21.tar.bz2 iso/docker-$(DOCKER_VERSION).tgz \
		iso/cross-compiler-x86_64.tar.bz2 iso/busybox-$(BUSYBOX_VERSION).tar.bz2 \
		iso/dropbear-$(DROPBEAR_VERSION).tar.bz2
	$(VAGRANT) suspend
	$(VAGRANT) up $(ISO_BUILDER) --no-provision
	$(VAGRANT) provision $(ISO_BUILDER)
	$(VAGRANT) suspend $(ISO_BUILDER)

iso/linux-$(KERNEL_VERSION).tar.xz:
	cd iso && curl -OL https://www.kernel.org/pub/linux/kernel/v3.x/linux-$(KERNEL_VERSION).tar.xz

iso/iptables-1.4.21.tar.bz2:
	cd iso && curl -OL http://www.netfilter.org/projects/iptables/files/iptables-1.4.21.tar.bz2

iso/docker-$(DOCKER_VERSION).tgz:
	cd iso && curl -OL https://get.docker.com/builds/Linux/x86_64/docker-$(DOCKER_VERSION).tgz

iso/cross-compiler-x86_64.tar.bz2:
	cd iso && curl -OL http://uclibc.org/downloads/binaries/0.9.30.1/cross-compiler-x86_64.tar.bz2

iso/busybox-$(BUSYBOX_VERSION).tar.bz2:
	cd iso && curl -OL http://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

iso/dropbear-$(DROPBEAR_VERSION).tar.bz2:
	cd iso && curl -OL https://matt.ucc.asn.au/dropbear/releases/dropbear-$(DROPBEAR_VERSION).tar.bz2

boot_test: install
	$(VAGRANT) destroy -f $(BOX_TESTER)
	$(VAGRANT) up $(BOX_TESTER) --no-provision

test: boot_test
	$(VAGRANT) provision $(BOX_TESTER)
	@echo "-----> docker version"
	@docker version
	@echo "-----> docker images -t"
	@docker images -t
	@echo "-----> docker ps -a"
	@docker ps -a
	@echo "-----> nc localhost 8080"
	@nc localhost 8080
	@echo "-----> /etc/os-release"
	@vagrant ssh $(BOX_TESTER) -c "cat /etc/os-release" -- -T
	@echo "-----> hostname"
	@vagrant ssh $(BOX_TESTER) -c "hostname" -- -T
	@echo "-----> /etc/network/interfaces"
	@vagrant ssh $(BOX_TESTER) -c "cat /etc/network/interfaces" -- -T
	@echo "-----> route"
	@vagrant ssh $(BOX_TESTER) -c "route" -- -T
	@echo "-----> df"
	@vagrant ssh $(BOX_TESTER) -c "df" -- -T
	@echo '-----> docker exec `docker ps -l -q` ls -l'
	@docker exec `docker ps -l -q` ls -l
	$(VAGRANT) suspend $(BOX_TESTER)

clean:
	$(VAGRANT) destroy -f
	$(RM) $(BOX_NAME)
	$(RM) $(HDD_NAME)
	$(RM) $(ISO_NAME)

.PHONY: box hdd iso install test clean
