Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # --- Настройки VirtualBox ---
  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end

  # ==========================================
  # SERVER (Prometheus + Grafana + Node Exporter)
  # ==========================================
  config.vm.define "server" do |server|
    server.vm.hostname = "server.local"
    server.vm.network "private_network", ip: "192.168.56.10"
    server.vm.network "forwarded_port", guest: 22, host: 22220, id: "ssh", auto_correct: true
    server.vm.network "forwarded_port", guest: 9090, host: 19090, auto_correct: true
    server.vm.network "forwarded_port", guest: 3000, host: 13000, auto_correct: true
    
    server.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end

    server.vm.provision "shell", path: "scripts/server-setup.sh"
  end

  # ==========================================
  # AGENT 1 (Node Exporter)
  # ==========================================
  config.vm.define "agent1" do |agent1|
    agent1.vm.hostname = "agent1.local"
    agent1.vm.network "private_network", ip: "192.168.56.11"
    agent1.vm.network "forwarded_port", guest: 22, host: 22221, id: "ssh", auto_correct: true
    
    agent1.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end

    agent1.vm.provision "shell", path: "scripts/agent-setup.sh"
  end

  # ==========================================
  # AGENT 2 (Node Exporter)
  # ==========================================
  config.vm.define "agent2" do |agent2|
    agent2.vm.hostname = "agent2.local"
    agent2.vm.network "private_network", ip: "192.168.56.12"
    agent2.vm.network "forwarded_port", guest: 22, host: 22222, id: "ssh", auto_correct: true
    
    agent2.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end

    agent2.vm.provision "shell", path: "scripts/agent-setup.sh"
  end
end