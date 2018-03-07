# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  # common centos image for all VMs
  config.vm.box = "puppetlabs/centos-7.0-64-nocm"
  # use the vagrant cachier plugin to keep packages in cache.
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
    config.vbguest.no_install = true
  end

  # lets create 2 VMs
  config.vm.define "app1" do |app1|
    app1.vm.hostname = "app1"
    app1.vm.network "private_network", ip: "192.168.61.71"

    app1.ssh.insert_key = false if (Vagrant::VERSION == "1.8.5") # https://github.com/mitchellh/vagrant/issues/7610
  end

  config.vm.define "app2" do |app2|
    app2.vm.hostname = "app2"
    app2.vm.network "private_network", ip: "192.168.61.72"

    app2.ssh.insert_key = false if (Vagrant::VERSION == "1.8.5") # https://github.com/mitchellh/vagrant/issues/7610
  end

  config.vm.define "buildserver" do |buildserver|
    buildserver.vm.hostname = "buildserver"
    buildserver.ssh.insert_key = false if (Vagrant::VERSION == "1.8.5") # https://github.com/mitchellh/vagrant/issues/7610
  
    buildserver.vm.network :private_network, ip: "192.168.61.70"

    # if Vagrant.has_plugin?("vagrant-cachier")
    #   buildserver.cache.scope = :box
    # end
  
    # if Vagrant.has_plugin?("vagrant-vbguest")
    #   buildserver.vbguest.auto_update = false
    #   buildserver.vbguest.no_install = true
    # end
  
    buildserver.vm.network "forwarded_port", guest: 80, host: 8180, id: "nginx_port", auto_correct: true
    buildserver.vm.network "forwarded_port", guest: 8080, host: 8280, id: "tomcat_web_app_port", auto_correct: true

    # first task is to install ansible on the guest buildserver
    buildserver.vm.provision "install-ansible", type: "shell", path: "scripts/install_ansible.sh"

    # install nginx in buildserver
    buildserver.vm.provision "install-nginx", type: "ansible_local" do |ansible|
      ansible.verbose = false
      ansible.playbook = "install-nginx.yml"
      ansible.inventory_path = "local.inventory"
    end

    # checking the status of nginx and if it is listening on port 80
    buildserver.vm.provision "check-nginx-port", type: "shell", path: "scripts/check-nginx-status.sh"

    # promote vagrant user to sudo without password and
    # allow anyone in admin group to sudo with a pasword
    buildserver.vm.provision "sudoer-task", type: "ansible_local" do |ansible|
      ansible.verbose = false
      ansible.playbook = "privilege_auth.yml"
      ansible.inventory_path = "local.inventory"
    end

    # Deploy the weather app only in buildserver
    buildserver.vm.provision "deploy-app", type: "ansible_local" do |ansible|
      ansible.verbose = false
      ansible.playbook = "deploy-web-app.yml"
      ansible.limit = "build-server"
      ansible.inventory_path = "local.inventory"
    end

    # Configure nginx to proxy weather app for 1 server only
    buildserver.vm.provision "proxy-nginx", type: "ansible_local" do |ansible|
      ansible.verbose = false
      ansible.playbook = "configure-nginx-for-webapp.yml"
      ansible.inventory_path = "local.inventory"
    end

=begin
    Now we'll deploy the weather app to 2 more server and then use the nginx
    to load balance requests between the 3 instances.

    To achieve this, we'll need 2 more instances which have already been created in
    the first step. Now we'll simply use the VMs for deploying web-app.
=end

    # deploy the weather app into the 2 instances and update nginx to load balance.
    buildserver.vm.provision "deploy-and-load-balance", type: "ansible_local" do |ansible|
      ansible.verbose = false
      ansible.playbook = "deploy-and-load-balance.yml"
      ansible.limit = "all"
      ansible.inventory_path = "local.inventory"
    end

    # test the loadbalancer and see if both nodes are being used
    # it will output either 192.168.61.71 (app1) or 192.168.61.72 (app2) to the console
    buildserver.vm.provision "test-load-balancer", type: "shell", path: "scripts/test-load-balancer.sh"

  end
end