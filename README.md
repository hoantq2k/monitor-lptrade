# Docker Swarm Monitoring Exporters

Stack Docker Swarm cho:

- Prometheus
- node_exporter
- cAdvisor
- Alertmanager (+ prometheus_msteams bridge)
- postgres_exporter (chi cum DMZ)
- blackbox_exporter
- redis_exporter (chi cum DMZ)

## Mo hinh 2 cum

Ha tang openapiconfig van hanh **hai Docker Swarm cluster doc lap**, moi cum
co monitoring stack rieng deploy tren manager cua chinh cum do:

| Cum | Overlay app | Stack app | Monitoring co gi                                                                                              |
|-----|-------------|-----------|--------------------------------------------------------------------------------------------------------------|
| DMZ | `nw_dmz`    | `tools`, `fedmz`, `feweb`, `fegw` | Full: node_exporter, cadvisor, prometheus, alertmanager, teams bridge, postgres_exporter, redis_exporter x5, haproxy_exporter x2 (bps + dmz), blackbox (haproxy/postgres/rabbit/redis) |
| MID | `backend`   | `femid`   | node_exporter, cadvisor, prometheus, alertmanager, teams bridge, haproxy_exporter (femid), blackbox (haproxy + bpsbase/report/reportbroker/external) |

Hai monitoring stack **khong** noi voi nhau qua overlay Swarm. Neu can view
tap trung, dung chung Alertmanager receiver (webhook Teams) hoac them Grafana
ngoai Swarm tro toi 2 Prometheus (`<dmz-manager>:9090`, `<mid-manager>:9090`).

## Cau truc file theo cum

```
docker-stack-exporters-dmz.yml   # Stack cho cum DMZ (attach nw_dmz)
docker-stack-exporters-mid.yml   # Stack cho cum MID (attach backend)
prometheus/prometheus.dmz.yml    # Scrape config cua Prometheus DMZ
prometheus/prometheus.mid.yml    # Scrape config cua Prometheus MID
prometheus/rules.yml             # Alert rules dung chung 2 cum
alertmanager/alertmanager.yml    # Template Alertmanager (goi ra Teams)
blackbox/blackbox.yml            # Module blackbox dung chung
.env.dmz                         # Env cho cum DMZ (committed, gia tri co dinh)
.env.mid                         # Env cho cum MID (committed, gia tri co dinh)
```

Hai file `.env.dmz` va `.env.mid` duoc commit voi cac gia tri co dinh (image
tag, registry, webhook, DSN, ACL). Khong can copy hay chinh sua truoc khi
deploy. Neu can override tren mot manager cu the (vi du doi Redis password
o UAT khac PROD), sua truc tiep tren manager do va giu thay doi ngoai git,
hoac tao commit rieng cho moi truong.

## Prerequisites tren tung cum

### Overlay networks

Trong swarm DMZ:

- Overlay `nw_dmz` phai ton tai (do cum tools/fedmz tao) va attachable.
- Overlay `monitoring` se duoc tao tu dong neu chua co.

Trong swarm MID:

- Overlay `backend` phai ton tai (do cum femid tao) va attachable.
  Neu chua attachable, chay `docker network create backend -d overlay --attachable`
  truoc khi deploy `femid`.
- Overlay `monitoring` se duoc tao tu dong neu chua co.

### Node label `monitor=true` (bat buoc)

Prometheus va Alertmanager dung volume local (`prometheus_data`,
`alertmanager_data`) tren node ma task chay. Neu de placement mac dinh
`node.role == manager`, khi task nhay sang manager khac volume tren node moi
rong => mat toan bo TSDB va silence state.

Vi vay tat ca service (tru `node_exporter` va `cadvisor` chay global) deu pin
ve node co label `monitor=true`:

- prometheus, alertmanager, prometheus_msteams
- postgres_exporter, blackbox_exporter (chi DMZ)
- redis_exporter_master, redis_exporter_slave, redis_exporter_socket, redis_exporter_market, redis_exporter_pubsub (chi DMZ)

Truoc lan deploy dau tien tren moi cum, chay lenh sau tren manager cua cum
tuong ung. Thay `<hostname>` bang hostname xuat hien trong `docker node ls`:

Cum DMZ (chay tren mot trong ba manager DMZ, vi du opuser@10.8.11.111):

```bash
# Liet ke node de xem hostname
docker node ls
# Gan label cho node duoc chon
docker node update --label-add monitor=true <hostname>
# Xac nhan
docker node inspect <hostname> --format '{{ .Spec.Labels }}'
```

Cum MID (chay tren mot trong ba manager MID, vi du opuser@10.8.14.111): lenh
giong het, chi doi hostname.

Chi gan label tren dung mot node cho moi cum. Neu node do bi thay the:

```bash
# Node cu (neu con): go label
docker node update --label-rm monitor=true <old-hostname>

# Optional: neu muon giu TSDB history va silence, copy volume tu node cu sang
# node moi (chay voi quyen root):
scp -r <old-node>:/var/lib/docker/volumes/monitor_prometheus_data \
       <new-node>:/var/lib/docker/volumes/
scp -r <old-node>:/var/lib/docker/volumes/monitor_alertmanager_data \
       <new-node>:/var/lib/docker/volumes/

# Node moi: gan label
docker node update --label-add monitor=true <new-hostname>
```

`scripts/deploy-common.sh` se refuse deploy neu khong tim thay node nao mang
label `monitor=true` tren swarm cua cum tuong ung.

`node_exporter` va `cadvisor` chay `mode: global` (mot task tren moi node) de
lay metrics cua tung host; khong bi anh huong boi label.

### HAProxy stats

HAProxy 1.8 (image `haproxy:1.8-alpine`) khong co Prometheus exporter native
nen stack them `prom/haproxy-exporter` sidecar, moi HAProxy mot exporter,
doc CSV stats qua HTTP tren cong 9000. Thong tin xac thuc lay tu bien
`HAPROXY_STATS_USER` / `HAPROXY_STATS_PASSWORD` trong `.env.<cluster>`
(mac dinh `admin:admin` khop cac file `bps-haproxy.cfg`, `swarm-*-haproxy.cfg`).

HAProxy targets duoc monitor:
- DMZ: `tools_bps_haproxy` (routes DMZ->MID) va `fedmz_haproxy` (front-facing).
- MID: `femid_haproxy`.

Neu them HAProxy khac (vi du deploy stack `fegw` co `fegw_haproxy`), copy
mot service `haproxy_exporter_<ten>` trong stack YAML tuong ung roi doi
`--haproxy.scrape-uri`; Prometheus tu discover qua regex
`.+_haproxy_exporter_.+`, khong can chinh scrape config.

Alert phat sinh:
- `HAProxyServerDown` (warning): mot upstream cu the trong backend DOWN.
- `HAProxyBackendKhongCoServer` (critical): toan bo backend khong con server.
- `HAProxyExporterKhongLayDuocStats` (warning): exporter khong ket noi
  duoc stats (mat HAProxy hoac sai credential).

### RabbitMQ Prometheus plugin

RabbitMQ native metrics can bat tren cum DMZ (khong can tren MID):

```bash
rabbitmq-plugins enable rabbitmq_prometheus
```

## Deploy

Tren manager DMZ:

```bash
./start.sh dmz         # hoac ./start-dmz.sh
./redeploy.sh dmz
./stop.sh dmz
```

Tren manager MID:

```bash
./start.sh mid         # hoac ./start-mid.sh
./redeploy.sh mid
./stop.sh mid
```

Ba script goc `start.sh` / `redeploy.sh` / `stop.sh` bat buoc phai truyen
`dmz` hoac `mid` de tranh trien khai nham cum. Cac ban goc khong doi so con
duoc thay bang tap script `-dmz.sh` / `-mid.sh` tuong duong.

Script `scripts/deploy-common.sh` va `scripts/stop-common.sh` yeu cau bien
moi truong `CLUSTER=dmz|mid`; cac wrapper `-dmz.sh` / `-mid.sh` set san bien
nay.

## Endpoint sau khi deploy

Tren tung cum, cac service resolve trong overlay `monitoring`:

```text
Prometheus:          http://prometheus:9090
node_exporter:       http://tasks.node_exporter:9100/metrics
cAdvisor:            http://tasks.cadvisor:8080/metrics
Alertmanager:        http://alertmanager:9093
Teams bridge:        http://prometheus_msteams:2000
blackbox_exporter:   http://blackbox_exporter:9115/probe
```

Truy cap tu ngoai qua ingress port 9090 (Prometheus) va 9093 (Alertmanager)
tren bat ky node nao cua cum tuong ung.

## Label `cluster`

Prometheus DMZ ghi label `cluster=dmz` cho moi target, MID ghi `cluster=mid`.
Neu ban gop 2 Prometheus vao mot Grafana, dung label nay de tach dashboard.

## Post-deploy verification

Cho tung cum, chay tren manager tuong ung:

```bash
docker stack services monitor
docker stack ps monitor --no-trunc
```

Sau do kiem tra:

- Prometheus `/targets` liet ke dung service cua cum (`tools_*` cho DMZ,
  `femid_*` cho MID) va tat ca len UP.
- Prometheus `/rules` load rule khong loi parse.
- Alertmanager `/-/ready` tra 200.
- Prometheus co the goi Teams bridge: xem log `prometheus_msteams` service.

Khong ket luan cum "healthy" chi vi `docker stack deploy` khong bao loi.

## Grafana

Grafana chay ngoai Swarm. Them 2 datasource Prometheus, mot cho tung cum;
neu dung Grafana chung, dung label `cluster` de filter dashboard.

### Dashboard "Swarm Service Wallboard" (chinh)

File `grafana/dashboards/service-wallboard.json` la wallboard realtime cho
NOC/on-call: moi service la mot o vuong, XANH = UP, DO = DOWN, refresh moi
10 giay. Khong bieu do, khong lich su — chi trang thai hien tai.

Cac o duoc chia thanh 4 khu vuc:
- **HAProxy upstreams**: moi o = mot upstream server (haproxy_target/backend/server).
  Day la khu vuc chinh vi HAProxy da health-check goi tung task backend.
- **Databases & queues**: PostgreSQL, Redis (5 role), RabbitMQ.
- **Nodes**: mot o cho moi Swarm node (dua tren node_exporter).
- **Blackbox probes**: mot o cho moi TCP probe (haproxy stats, DB ports,
  API ports MID).

Import cach lam: giong dashboard duoi. Recommend mo full-screen (kiosk mode)
tren TV/monitor lon: URL them `?kiosk=tv&refresh=10s`.

### Dashboard "Host Metrics"

File `grafana/dashboards/host-metrics.json`. CPU / RAM / Disk / IO / Network
chi tiet cua tung Swarm node. Data tu node_exporter chay global. Panel gom:

- **Summary**: tong node, node DOWN, max CPU %, max RAM %, max Disk % — thay
  ngay cum nao dang gap ap luc tai nguyen.
- **CPU**: usage % theo node, load avg 1/5/15m, breakdown theo mode (user /
  system / iowait / softirq).
- **Memory**: usage %, breakdown (used / cached / buffers), swap used.
- **Disk**: bang % used theo tung mountpoint (gauge trong bang), disk free
  bytes, inode usage % (canh bao khi day inode dang khi disk).
- **Disk IO**: throughput bytes/s, IOPS, IO time %, queue depth.
- **Network**: throughput RX/TX theo interface (loc bo lo/docker/veth), loi
  va drop packet, TCP connections (ESTABLISHED / TIME_WAIT).

Bien filter: `Cum` va `Node`. Refresh 30s.

### Dashboard "HAProxy Traffic & Latency"

File `grafana/dashboards/haproxy-traffic.json`. Phan tich chi tiet luu luong
qua HAProxy: request rate, response codes (2xx/3xx/4xx/5xx), latency, queue,
session, bytes. Bien filter theo `Cum`, `HAProxy target`, `Backend`.

Ket hop voi `service-wallboard` de biet "cai gi DOWN" va dashboard nay de
biet "traffic anh huong the nao" khi co su co.

### Dashboard "Container Metrics"

File `grafana/dashboards/container-metrics.json`. Chi tiet CPU, RAM, Network,
Restart cua tung Swarm service (cadvisor). Gom:

- **Top 10 consumers**: CPU va RAM (bar gauge horizontal).
- **CPU per service**: aggregate va break theo tung task (container instance)
  de xem replica nao chay nong hon.
- **RAM per service** va **% RAM tren memory limit** (chi hien service co dat
  limit — bat container gan cham limit truoc khi OOM).
- **Container network RX/TX** theo service.
- **Container restarts (15m)**: neu > 1 lien tuc = crash loop.
- **So container running theo service**: bang liet ke replicas thuc te.

Bien filter: `Cum` va `Service` (multi-select).

### Dashboard "Swarm Service Status" (analytical, phu tro)

File `grafana/dashboards/service-status.json` la starter dashboard tap trung
vao trang thai upstream server qua HAProxy. Import cach lam:

1. Grafana UI -> Dashboards -> Import -> Upload JSON file, chon file
   `grafana/dashboards/service-status.json`.
2. O buoc Options, chon Prometheus datasource. Neu co ca DMZ va MID, chon
   mot va sau khi mo dashboard dung dropdown `Cum` (`cluster`) de filter.
3. Save.

Dashboard co san:
- **Summary**: tong upstream, so UP, so DOWN, so backend chet 100%.
- **Server hien DOWN**: bang liet ke `haproxy_target/backend/server/cluster`
  cua tung upstream dang DOWN (nguon action cho on-call).
- **Timeline UP/DOWN**: state timeline cho tung upstream server; do = DOWN,
  xanh = UP; xem lich su len xuong theo thoi gian.
- **% Server UP theo backend**: bieu do phan tram server UP tren tong so
  server cua tung backend HAProxy — thay ngay backend nao suy giam.
- **So do topology (Node Graph)**: HAProxy target -> backend -> server
  duoi dang do thi node-edge. Node Graph panel yeu cau data theo format
  chuan cua Grafana; transformation trong dashboard co gang shape sat nhat
  co the nhung neu Grafana version doi thi co the can chinh field mapping
  (id/title/source/target). Neu panel bao "Data does not match", xoa panel
  va xem cac panel table/timeline ben tren van du dung.

Neu can them Node Graph tot hon (ke ca dependency giua service via HAProxy
frontend), can xay dung 2 query rieng cho nodes va edges roi join. Setup do
phuc tap hon starter nay; co the mo rong sau khi dashboard co san hoat dong.

### Dashboard cong dong bo sung

- [Node Exporter Full - ID 1860](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
- [PostgreSQL Database - ID 9628](https://grafana.com/grafana/dashboards/9628-postgresql-database/) (chi cum DMZ)
- [RabbitMQ Overview - ID 10991](https://grafana.com/grafana/dashboards/10991-rabbitmq-overview/) (chi cum DMZ)
- [Prometheus 2.0 Overview - ID 3662](https://grafana.com/grafana/dashboards/3662-prometheus-2-0-overview/)
- [HAProxy 2 Full - ID 12693](https://grafana.com/grafana/dashboards/12693-haproxy-2-full/) hoac [HAProxy - ID 367](https://grafana.com/grafana/dashboards/367-haproxy/) (khop metrics tu prom/haproxy-exporter)

Dashboard cadvisor chi tiet cho Swarm co the dung label
`container_label_com_docker_swarm_service_name`.

## Mirror image

Neu can mirror image ve registry noi bo, sua `DOCKER_HUB_NAMESPACE` trong
`.env.dmz` / `.env.mid`, dang nhap `docker login`, roi chay:

```bash
./push-images.sh
```

## Ghi chu ve cAdvisor va Docker data-root

Neu Docker daemon cua node dung `data-root != /var/lib/docker` (vi du openapi
config dung `/app/docker`), phai dat `DOCKER_DATA_ROOT=/app/docker` trong
file `.env.<cluster>`. Neu khong, cAdvisor se mount rong va khong lay duoc
container fs metrics.
