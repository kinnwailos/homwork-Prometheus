# My VM Monitoring Stack

Проект поднимает 3 виртуальные машины через Vagrant:

- `server` - Prometheus + Grafana + Node Exporter
- `agent1` - Node Exporter
- `agent2` - Node Exporter

## Быстрый старт

1. Поднять окружение:

```bash
vagrant up
```

2. Проверить статус:

```bash
vagrant status
```

3. Если конфиг менялся (например, порты), перезапустить `server`:

```bash
vagrant reload server
```

## Доступ из браузера (с хоста)

Используй адреса хоста, а не внутренний IP VM:

- Prometheus: `http://localhost:19090`
- Grafana: `http://localhost:13000`

Логин Grafana по умолчанию: `admin/admin`.

## Полезные команды

```bash
vagrant ssh server
vagrant ssh agent1
vagrant ssh agent2
```

Проброшенные SSH-порты:

- `server` -> `22220`
- `agent1` -> `22221`
- `agent2` -> `22222`

## Troubleshooting

- **Не открывается `192.168.56.10` в браузере**  
  Открывай через проброшенные порты хоста:
  - `http://localhost:19090`
  - `http://localhost:13000`

- **`vagrant ssh server` не подключается**  
  Проверь, что VM в статусе `running`:
  ```bash
  vagrant status
  ```
  Перезапусти VM:
  ```bash
  vagrant reload server
  ```

- **Сервисы внутри `server` не поднялись**  
  Зайди в VM и проверь статусы:
  ```bash
  vagrant ssh server -c "systemctl is-active prometheus grafana-server node_exporter"
  ```
  Если нужно, запусти провижининг повторно:
  ```bash
  vagrant provision server
  ```

- **Проблемы после изменения `Vagrantfile`**  
  Примени изменения перезапуском нужной VM:
  ```bash
  vagrant reload server
  ```
