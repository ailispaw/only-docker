require_relative "busybox_plugin.rb"

Vagrant.configure("2") do |config|
  config.ssh.shell = "sh"
  config.ssh.username = "root"

  # Forward the Docker port
  config.vm.network :forwarded_port, guest: 2375, host: 2375, auto_correct: true

  # Disable synced folder by default
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider :virtualbox do |vb|
    vb.check_guest_additions = false
    vb.functional_vboxsf     = false

    vb.customize "pre-boot", [
      "storageattach", :id,
      "--storagectl", "IDE Controller",
      "--port", "0",
      "--device", "0",
      "--type", "dvddrive",
      "--medium", File.expand_path("../only-docker.iso", __FILE__),
    ]
  end
end
