# BusyBox has no sudo command.
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

# BusyBox has poweroff command.
require Vagrant.source_root.join("plugins/guests/linux/cap/halt.rb")
module VagrantPlugins
  module GuestLinux
    module Cap
      class Halt
        def self.halt(machine)
          begin
            machine.communicate.sudo("docker stop $(docker ps -q)")
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

# Add change_host_name guest capability
module VagrantPlugins
  module GuestLinux
    class Plugin < Vagrant.plugin("2")
      guest_capability("linux", "change_host_name") do
        Cap::ChangeHostName
      end
    end

    module Cap
      class ChangeHostName
        def self.change_host_name(machine, name)
          machine.communicate.tap do |comm|
            if !comm.test("hostname -f | grep '^#{name}$' || hostname -s | grep '^#{name}$'")
              comm.sudo("hostname #{name}")
            end
          end
        end
      end
    end
  end
end

# Add configure_networks guest capability
module VagrantPlugins
  module GuestLinux
    class Plugin < Vagrant.plugin("2")
      guest_capability("linux", "configure_networks") do
        Cap::ConfigureNetworks
      end
    end

    module Cap
      class ConfigureNetworks
        include Vagrant::Util

        def self.configure_networks(machine, networks)
          machine.communicate.tap do |comm|
            # First, remove any previous network modifications
            # from the interface file.
            comm.sudo("sed -e '/^#VAGRANT-BEGIN/,$ d' /etc/network/interfaces > /tmp/vagrant-network-interfaces.pre")
            comm.sudo("sed -ne '/^#VAGRANT-END/,$ p' /etc/network/interfaces | tail -n +2 > /tmp/vagrant-network-interfaces.post")

            # Accumulate the configurations to add to the interfaces file as
            # well as what interfaces we're actually configuring since we use that
            # later.
            interfaces = Set.new
            entries = []
            networks.each do |network|
              interfaces.add(network[:interface])
              entry = TemplateRenderer.render("guests/debian/network_#{network[:type]}",
                                              options: network)

              entries << entry
            end

            # Perform the careful dance necessary to reconfigure
            # the network interfaces
            temp = Tempfile.new("vagrant")
            temp.binmode
            temp.write(entries.join("\n"))
            temp.close

            comm.upload(temp.path, "/tmp/vagrant-network-entry")

            # Bring down all the interfaces we're reconfiguring. By bringing down
            # each specifically, we avoid reconfiguring eth0 (the NAT interface) so
            # SSH never dies.
            interfaces.each do |interface|
              comm.sudo("ifdown eth#{interface} 2> /dev/null")
              comm.sudo("ip addr flush dev eth#{interface} 2> /dev/null")
            end

            comm.sudo('cat /tmp/vagrant-network-interfaces.pre /tmp/vagrant-network-entry /tmp/vagrant-network-interfaces.post > /etc/network/interfaces')
            comm.sudo('rm -f /tmp/vagrant-network-interfaces.pre /tmp/vagrant-network-entry /tmp/vagrant-network-interfaces.post')

            # Bring back up each network interface, reconfigured
            interfaces.each do |interface|
              comm.sudo("ifup eth#{interface}")
            end
          end
        end
      end
    end
  end
end

# Skip checking nfs client, because mount supports nfs.
require Vagrant.source_root.join("plugins/guests/linux/cap/nfs_client.rb")
module VagrantPlugins
  module GuestLinux
    module Cap
      class NFSClient
        def self.nfs_client_installed(machine)
          true
        end
      end
    end
  end
end

# Skip ensure_installed for Docker Provisioner
require Vagrant.source_root.join("plugins/provisioners/docker/installer.rb")
module VagrantPlugins
  module DockerProvisioner
    class Installer
      def ensure_installed
      end
    end
  end
end
