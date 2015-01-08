# Only Docker has no sudo command.
require Vagrant.source_root.join("plugins/communicators/ssh/communicator.rb")
module VagrantPlugins
  module CommunicatorSSH
    # This class provides communication with the VM via SSH.
    class Communicator < Vagrant.plugin("2", :communicator)
      def sudo(command, opts=nil, &block)
        # Run `execute` but with the `sudo` option.
        # opts = { sudo: true }.merge(opts || {})
        execute(command, opts, &block)
      end
    end
  end
end

# Only Docker has poweroff command of busybox.
require Vagrant.source_root.join("plugins/guests/linux/cap/halt.rb")
module VagrantPlugins
  module GuestLinux
    module Cap
      class Halt
        def self.halt(machine)
          begin
            machine.communicate.sudo("poweroff -f")
          rescue IOError
            # Do nothing, because it probably means the machine shut down
            # and SSH connection was lost.
          end
        end
      end
    end
  end
end

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
