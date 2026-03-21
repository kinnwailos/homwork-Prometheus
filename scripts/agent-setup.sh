#!/bin/bash
set -e  # Останавливать скрипт при любой ошибке

echo ">>> [AGENT] Начало настройки..."

# Обновление пакетов
echo ">>> [AGENT] Обновление пакетов..."
apt-get update -y

# Проверка, установлен ли уже Node Exporter
if [ -f /usr/local/bin/node_exporter ]; then
    echo ">>> [AGENT] Node Exporter уже установлен, пропускаем..."
else
    echo ">>> [AGENT] Установка Node Exporter..."
    
    # Создание пользователя
    if ! id "prometheus" &>/dev/null; then
        useradd --no-create-home --shell /bin/false prometheus
    fi
    
    # Скачивание и установка
    cd /tmp
    wget -q --show-progress https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar -xzf node_exporter-1.7.0.linux-amd64.tar.gz
    cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/node_exporter
    rm -rf node_exporter-1.7.0.linux-amd64*
    
    # Создание сервиса
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
    echo ">>> [AGENT] Node Exporter установлен и запущен!"
fi

# Установка GUI (только если не установлен)
if [ ! -f /usr/bin/startxfce4 ]; then
    echo ">>> [AGENT] Установка графического интерфейса..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y xubuntu-desktop
    systemctl set-default graphical.target
else
    echo ">>> [AGENT] GUI уже установлен, пропускаем..."
fi

# Добавляем сервер в hosts
grep -q "server.local" /etc/hosts || echo "192.168.56.10 server server.local" >> /etc/hosts

echo ">>> [AGENT] Настройка завершена!"