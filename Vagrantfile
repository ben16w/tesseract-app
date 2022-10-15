# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.ssh.insert_key = false

  config.vm.network "private_network", ip: "192.168.56.11"

  config.vm.synced_folder ".", "/vagrant_data", disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y python3-setuptools python3-pip unzip git zip
  SHELL
end
