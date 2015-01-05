
only-docker.iso: Vagrantfile Dockerfile \
	assets/console-container.sh assets/init assets/isolinux.cfg assets/kernel_config \
	linux-3.18.1.tar.xz iptables-1.4.21.tar.bz2 docker-1.4.1.tgz
	vagrant up --no-provision
	vagrant provision

linux-3.18.1.tar.xz:
	curl -OL https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.18.1.tar.xz

iptables-1.4.21.tar.bz2:
	curl -OL http://www.netfilter.org/projects/iptables/files/iptables-1.4.21.tar.bz2

docker-1.4.1.tgz:
	curl -OL https://get.docker.com/builds/Linux/x86_64/docker-1.4.1.tgz

clean:
	rm -f only-docker.iso
	vagrant destroy -f

.PHONY: clean
