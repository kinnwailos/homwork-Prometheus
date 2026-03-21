#!/bin/bash
echo ">>> [SERVER] Начало настройки..."
apt-get update

# --- Установка Node Exporter ---
echo ">>> [SERVER] Установка Node Exporter..."
useradd --no-create-home --shell /bin/false prometheus
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar -xzf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter

# --- Установка Prometheus ---
echo ">>> [SERVER] Установка Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz
cp prometheus-2.48.0.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.48.0.linux-amd64/promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
mkdir -p /etc/prometheus /var/lib/prometheus
cp -r prometheus-2.48.0.linux-amd64/consoles /etc/prometheus/
cp -r prometheus-2.48.0.linux-amd64/console_libraries /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'server'
    static_configs:
      - targets: ['192.168.56.10:9100']
  
  - job_name: 'agent1'
    static_configs:
      - targets: ['192.168.56.11:9100']
  
  - job_name: 'agent2'
    static_configs:
      - targets: ['192.168.56.12:9100']
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now prometheus

# --- Установка Grafana ---
echo ">>> [SERVER] Установка Grafana..."
apt-get install -y apt-transport-https software-properties-common
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana
systemctl enable --now grafana-server

# --- Установка GUI ---
echo ">>> [SERVER] Установка графического интерфейса..."
DEBIAN_FRONTEND=noninteractive apt-get install -y xubuntu-desktop
systemctl set-default graphical.target

echo ">>> [SERVER] Готово!"
echo "Prometheus: http://192.168.56.10:9090"
echo "Grafana:    http://192.168.56.10:3000 (admin/admin)"
