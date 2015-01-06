# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "yungsang/boot2docker"

  config.vm.define "only-docker-iso" do |iso|
    iso.vm.provider :virtualbox do |vb|
      vb.name = "only-docker-iso"
    end

    iso.vm.network :forwarded_port, guest: 2375, host: 2375, disabled: true

    iso.vm.synced_folder ".", "/vagrant"

    iso.vm.provision :docker do |d|
      d.build_image "/vagrant/", args: "-t only-docker"
      d.run "only-docker", args: "--rm", cmd: "> /vagrant/only-docker.iso",
        auto_assign_name: false, daemonize: false
    end
  end

  config.vm.define "only-docker-hdd" do |hdd|
    hdd.vm.provider :virtualbox do |vb|
      vb.name = "only-docker-hdd"

      vb.customize [
        "createhd",
        "--filename", "only-docker",
        "--size", "40960",
        "--format", "VDI",
      ]
      vb.customize [
        "storageattach", :id,
        "--storagectl", "SATA Controller",
        "--port", "1",
        "--device", "0",
        "--type", "hdd",
        "--medium", "only-docker.vdi",
      ]
    end

    hdd.vm.network :forwarded_port, guest: 2375, host: 2375, disabled: true

    hdd.vm.provision :shell do |s|
      s.inline = <<-EOT
        sudo mkfs.ext4 -F /dev/sdb
      EOT
    end
  end

  config.vm.define "only-docker-test" do |box|
    box.vm.box = "only-docker"

    box.vm.provider :virtualbox do |vb|
      vb.name = "only-docker-test"
      vb.gui = true
    end
  end
end
