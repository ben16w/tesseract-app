# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.ssh.insert_key = false

  config.vm.network "private_network", ip: "192.168.56.11"

  config.vm.synced_folder ".", "/vagrant_data", disabled: true

  config.vm.provision "shell", inline: <<-SHELL
    if [ ! -f /provisioned ]; then  
      apt-get update
      apt-get install -y python3-setuptools python3-pip unzip git zip
      touch /provisioned
    fi
  SHELL

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
    ansible.extra_vars = {
      ansible_connection: "ssh",
      ansible_user: "vagrant",
      ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key",
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no',
      ansible_python_interpreter: "/usr/bin/python3"
    }
  end
end
