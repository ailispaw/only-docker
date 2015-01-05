# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "only-docker-builder"

  config.vm.box = "yungsang/boot2docker"

  config.vm.synced_folder ".", "/vagrant"

  # Adjust datetime after suspend and resume
  config.vm.provision :shell do |s|
    s.inline = <<-EOT
      sudo /usr/local/bin/ntpclient -s -h pool.ntp.org
      date
    EOT
  end

  config.vm.provision :docker do |d|
    d.build_image "/vagrant/", args: "-t only-docker"
    d.run "only-docker", args: "--rm", cmd: "> /vagrant/only-docker.iso",
      auto_assign_name: false, daemonize: false
  end
end
