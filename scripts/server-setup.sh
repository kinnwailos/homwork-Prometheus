#!/bin/bash
set -euo pipefail

echo ">>> [SERVER] Начало настройки..."
apt-get update

# --- Установка Node Exporter ---
echo ">>> [SERVER] Установка Node Exporter..."
if ! id "prometheus" &>/dev/null; then
  useradd --no-create-home --shell /bin/false prometheus
fi
systemctl stop node_exporter >/dev/null 2>&1 || true
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar -xzf node_exporter-1.7.0.linux-amd64.tar.gz
# Обновляем бинарник через временный файл, чтобы избежать "Text file busy".
install -m 0755 node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/node_exporter.new
mv -f /usr/local/bin/node_exporter.new /usr/local/bin/node_exporter
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
systemctl stop prometheus >/dev/null 2>&1 || true
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz
install -m 0755 prometheus-2.48.0.linux-amd64/prometheus /usr/local/bin/prometheus.new
mv -f /usr/local/bin/prometheus.new /usr/local/bin/prometheus
install -m 0755 prometheus-2.48.0.linux-amd64/promtool /usr/local/bin/promtool.new
mv -f /usr/local/bin/promtool.new /usr/local/bin/promtool
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
mkdir -p /etc/prometheus /var/lib/prometheus
cp -r prometheus-2.48.0.linux-amd64/consoles /etc/prometheus/
cp -r prometheus-2.48.0.linux-amd64/console_libraries /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# --- Правила оповещений Prometheus ---
mkdir -p /etc/prometheus/alerts
cp /vagrant/configs/prometheus/node-exporter-alerts.yml /etc/prometheus/alerts/node-exporter.yml

cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - /etc/prometheus/alerts/*.yml

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

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml
chown -R prometheus:prometheus /etc/prometheus/alerts

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

# --- Установка Alertmanager ---
echo ">>> [SERVER] Установка Alertmanager..."
systemctl stop alertmanager >/dev/null 2>&1 || true
cd /tmp
wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xzf alertmanager-0.27.0.linux-amd64.tar.gz
install -m 0755 alertmanager-0.27.0.linux-amd64/alertmanager /usr/local/bin/alertmanager.new
mv -f /usr/local/bin/alertmanager.new /usr/local/bin/alertmanager
install -m 0755 alertmanager-0.27.0.linux-amd64/amtool /usr/local/bin/amtool.new
mv -f /usr/local/bin/amtool.new /usr/local/bin/amtool
chown prometheus:prometheus /usr/local/bin/alertmanager /usr/local/bin/amtool
mkdir -p /etc/alertmanager /var/lib/alertmanager
cp /vagrant/configs/alertmanager/alertmanager.yml /etc/alertmanager/alertmanager.yml
chown -R prometheus:prometheus /etc/alertmanager /var/lib/alertmanager

cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now alertmanager

# --- Установка Docker и cAdvisor ---
echo ">>> [SERVER] Установка Docker и cAdvisor..."
apt-get install -y docker.io
systemctl enable --now docker
docker rm -f cadvisor >/dev/null 2>&1 || true
docker run -d \
  --name=cadvisor \
  --restart unless-stopped \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:v0.49.1

# --- Установка Grafana ---
echo ">>> [SERVER] Установка Grafana..."
if dpkg -s grafana >/dev/null 2>&1; then
  echo ">>> [SERVER] Grafana уже установлена, пропускаю переустановку."
else
  apt-get install -y apt-transport-https software-properties-common
  if wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key; then
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update
    apt-get install -y grafana
  else
    echo ">>> [SERVER] Не удалось получить ключ Grafana repo, пропускаю установку Grafana."
  fi
fi

# --- Автоподключение Prometheus в Grafana (Provisioning) ---
echo ">>> [SERVER] Настройка Grafana datasource (Prometheus)..."
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards
cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

cp /vagrant/configs/grafana/dashboard-provisioning.yml /etc/grafana/provisioning/dashboards/dashboard.yml
cp /vagrant/configs/grafana/dashboards/docker-server-dashboard.json /var/lib/grafana/dashboards/docker-server-dashboard.json
chown -R grafana:grafana /var/lib/grafana/dashboards

systemctl enable grafana-server
systemctl restart grafana-server

# --- Установка GUI ---
echo ">>> [SERVER] Установка графического интерфейса..."
DEBIAN_FRONTEND=noninteractive apt-get install -y xubuntu-desktop
systemctl set-default graphical.target

echo ">>> [SERVER] Готово!"
echo "Prometheus: http://192.168.56.10:9090"
echo "Grafana:    http://192.168.56.10:3000 (admin/admin)"
