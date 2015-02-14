# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "yungsang/boot2docker"

  config.vm.define "only-docker-iso" do |iso|
    iso.vm.provider :virtualbox do |vb|
      vb.name = "only-docker-iso"
      vb.memory = 1024
    end

    iso.vm.network :forwarded_port, guest: 2375, host: 2375, disabled: true

    iso.vm.network "private_network", ip: "192.168.33.10"
    iso.vm.synced_folder ".", "/vagrant", type: "nfs"

    if Vagrant.has_plugin?("vagrant-triggers") then
      iso.trigger.after [:up, :resume] do
        info "Adjusting datetime after suspend and resume."
        run_remote "timeout -t 10 sudo /usr/local/bin/ntpclient -s -h pool.ntp.org; date"
      end
    end

    # Adjusting datetime before provisioning.
    iso.vm.provision :shell do |sh|
      sh.inline = "timeout -t 10 sudo /usr/local/bin/ntpclient -s -h pool.ntp.org; date"
    end

    iso.vm.provision :docker do |docker|
      docker.build_image "/vagrant/", args: "-t only-docker"
      docker.run "only-docker", args: "--rm", cmd: "> /vagrant/only-docker.iso",
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

    hdd.vm.provision :shell do |sh|
      sh.inline = <<-EOT
        sudo mkfs.ext4 -F /dev/sdb
      EOT
    end
  end

  config.vm.define "only-docker-test" do |test|
    test.vm.box = "only-docker"

    test.vm.hostname = "only-docker-test"

    test.vm.network "private_network", ip: "192.168.33.10"

    test.vm.synced_folder ".", "/vagrant", type: "nfs", mount_options: ["nolock", "vers=3", "udp"]

    test.vm.provider :virtualbox do |vb|
      vb.name = "only-docker-test"
      vb.gui = true
    end

    if Vagrant.has_plugin?("vagrant-triggers") then
      test.trigger.after [:up, :resume] do
        info "Adjusting datetime after suspend and resume."
        run_remote "timeout -t 10 ntpd -n -q -p pool.ntp.org || true"
      end
    end

    # Adjusting datetime before provisioning.
    test.vm.provision :shell do |sh|
      sh.privileged = false
      sh.inline = "timeout -t 10 ntpd -n -q -p pool.ntp.org || true"
    end

    test.vm.provision :docker do |d|
      d.pull_images "yungsang/busybox"
      d.run "simple-echo",
        image: "yungsang/busybox",
        args: "-p 8080:8080",
        cmd: "nc -p 8080 -l -l -e echo hello world!"
    end

    test.vm.network :forwarded_port, guest: 8080, host: 8080
  end
end
