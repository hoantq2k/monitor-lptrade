# Docker Swarm Monitoring Exporters

Stack Docker Swarm cho:

- Prometheus
- node_exporter
- cAdvisor
- Alertmanager
- postgres_exporter

## Cau hinh

Sua file `.env` o thu muc goc de doi ten stack, network, image tag va retention:

```text
.env
```

Ket noi PostgreSQL cho postgres_exporter nam trong bien `POSTGRES_DATA_SOURCE_NAME`.
Prometheus dung bien `PROMETHEUS_EXTERNAL_URL` de tao link quay lai UI trong alert; hay dat gia tri nay thanh URL/IP ma nguoi dung thuc su truy cap duoc.

Alertmanager gui canh bao ra Microsoft Teams qua bien `MS_TEAMS_WEBHOOK_URL`.
Khi deploy, script se render cau hinh Alertmanager tu `.env` ra `.generated/alertmanager.yml` va gui alert qua service `prometheus_msteams`.

Prometheus dang them label `host_ip` va ghi de `nodename` cho `node_exporter` bang IP trong label `instance`, de Grafana hien thi IP host thay vi container ID.
Voi `cadvisor`, Prometheus cung them `host_ip`, `nodename` va chuan hoa label `instance` ve IP host de dashboard cadvisor hien thi de nhin hon.

Neu can mirror image ve Docker Hub rieng, sua `DOCKER_HUB_NAMESPACE` trong `.env`, dang nhap `docker login`, roi chay:

```bash
./push-images.sh
```

Sau khi mirror, cac bien `*_IMAGE` trong `.env` dang tro ve registry noi bo `docker-hub.lpbsuat.com.vn:5000` va dung tag `latest`.

## Chay tren Linux

Chay toan bo stack:

```bash
./start.sh
```

Deploy lai toan bo stack:

```bash
./redeploy.sh
```

Stop toan bo stack:

```bash
./stop.sh
```

Neu can chay rieng tung cum, dung cac file trong `scripts/`:

```text
scripts/start-common.sh
scripts/stop-common.sh
scripts/redeploy-common.sh
scripts/start-postgres.sh
scripts/stop-postgres.sh
scripts/redeploy-postgres.sh
```

## Endpoint trong Swarm network

```text
Prometheus:          http://prometheus:9090
node_exporter:       http://tasks.node_exporter:9100/metrics
cAdvisor:            http://tasks.cadvisor:8080/metrics
Alertmanager:        http://alertmanager:9093
postgres_exporter:   http://postgres_exporter:9187/metrics
```
