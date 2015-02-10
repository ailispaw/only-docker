BOX_PACKER  := only-docker-box
HDD_BUILDER := only-docker-hdd
ISO_BUILDER := only-docker-iso
BOX_TESTER  := only-docker-test

BOX_NAME := only-docker.box
HDD_NAME := only-docker.vdi
ISO_NAME := only-docker.iso

VAGRANT := vagrant
VBOXMNG := VBoxManage

KERNEL_VERSION   := 3.18.6
DOCKER_VERSION   := 1.4.1
BUSYBOX_VERSION  := 1.23.1
DROPBEAR_VERSION := 2015.67

box: $(BOX_NAME)

hdd: $(HDD_NAME)

iso: $(ISO_NAME)

install: $(BOX_NAME)
	$(VAGRANT) box add -f only-docker $(BOX_NAME)

$(BOX_NAME): vagrantfile.tpl $(ISO_NAME) $(HDD_NAME) busybox_plugin.rb
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
	$(VBOXMNG) modifyvm $(BOX_PACKER) --ostype Linux26_64 --memory 512 --ioapic on --boot1 dvd
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nic1 nat --nictype1 82540EM --pae off
	$(VBOXMNG) storagectl $(BOX_PACKER) --name "IDE Controller" --add ide
	$(VBOXMNG) storagectl $(BOX_PACKER) --name "SATA Controller" --add sata
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype1 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype2 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype3 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype4 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype5 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype6 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype7 "82540EM"
	$(VBOXMNG) modifyvm $(BOX_PACKER) --nictype8 "82540EM"
	#
	# Attach HDD
	#
	$(VBOXMNG) storageattach $(BOX_PACKER) --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $(HDD_NAME)
	#
	# Package Box
	#
	$(RM) only-docker.box
	$(VAGRANT) package --base $(BOX_PACKER) --output $(BOX_NAME) --include $(ISO_NAME),busybox_plugin.rb --vagrantfile vagrantfile.tpl
	#
	# Detach HDD
	#
	$(VBOXMNG) storageattach $(BOX_PACKER) --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium none
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

$(ISO_NAME): Dockerfile \
	assets/console-container.sh assets/init assets/isolinux.cfg assets/kernel_config \
	linux-$(KERNEL_VERSION).tar.xz iptables-1.4.21.tar.bz2 docker-$(DOCKER_VERSION).tgz \
	cross-compiler-x86_64.tar.bz2 busybox-$(BUSYBOX_VERSION).tar.bz2 dropbear-$(DROPBEAR_VERSION).tar.bz2
	$(VAGRANT) up $(ISO_BUILDER) --no-provision
	$(VAGRANT) provision $(ISO_BUILDER)
	$(VAGRANT) suspend $(ISO_BUILDER)

linux-$(KERNEL_VERSION).tar.xz:
	curl -OL https://www.kernel.org/pub/linux/kernel/v3.x/linux-$(KERNEL_VERSION).tar.xz

iptables-1.4.21.tar.bz2:
	curl -OL http://www.netfilter.org/projects/iptables/files/iptables-1.4.21.tar.bz2

docker-$(DOCKER_VERSION).tgz:
	curl -OL https://get.docker.com/builds/Linux/x86_64/docker-$(DOCKER_VERSION).tgz

cross-compiler-x86_64.tar.bz2:
	curl -OL http://uclibc.org/downloads/binaries/0.9.30.1/cross-compiler-x86_64.tar.bz2

busybox-$(BUSYBOX_VERSION).tar.bz2:
	curl -OL http://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

dropbear-$(DROPBEAR_VERSION).tar.bz2:
	curl -OL https://matt.ucc.asn.au/dropbear/releases/dropbear-$(DROPBEAR_VERSION).tar.bz2

test: install
	$(VAGRANT) destroy -f $(BOX_TESTER)
	-$(VAGRANT) up $(BOX_TESTER)

clean:
	$(VAGRANT) destroy -f
	$(RM) $(BOX_NAME)
	$(RM) $(HDD_NAME)
	$(RM) $(ISO_NAME)

.PHONY: box hdd iso install test clean
