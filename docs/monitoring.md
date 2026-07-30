# Monitoramento

Prometheus + Grafana, mais exporters pro host e pro app que tem um banco de dados que vale a
pena observar de perto.

## Componentes

| Container | Papel |
|---|---|
| `prometheus` | coleta e armazena métricas, retenção de 15 dias |
| `grafana` | dashboards, acessível só através do proxy com basic auth abaixo |
| `grafana-proxy` (Caddy) | basic auth HTTP na frente do Grafana — uma segunda camada, definida em código, independente do login próprio do Grafana, em vez de um painel de controle de acesso na nuvem |
| `node-exporter` | CPU/RAM/disco/rede do host |
| `cadvisor` | uso de recursos por container |
| `postgres-exporter` | métricas do Postgres, entra na rede Docker interna do app, só leitura |
| `redis-exporter` | métricas do Redis, mesma rede |

Tudo roda na própria rede `monitoring`; `prometheus` e `grafana` não são publicados no host de
jeito nenhum — só o `grafana-proxy` é (em `127.0.0.1`), e só o Cloudflare Tunnel consegue
alcançá-lo.

## Acesso

`https://grafana.<dominio>` → Cloudflare Tunnel → `127.0.0.1:3001` (Caddy, basic auth) →
`grafana:3000` (login próprio do Grafana). Duas verificações de credencial independentes, ambas
definidas na configuração/`.env` deste repo, sem painel de terceiros pra configurar.

## Configuração

1. `cp .env.example .env` em `monitoring/`, preencha:
   - `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` — login próprio do Grafana
   - `GRAFANA_PROXY_USER` / `GRAFANA_PROXY_PASS_HASH` — a camada de basic auth do Caddy.
     Gere o hash com:
     ```bash
     docker run --rm caddy:2-alpine caddy hash-password --plaintext 'sua-senha'
     ```
   - `DATA_SOURCE_NAME` — `postgresql://usuario:senha@<container-postgres>:5432/<banco>?sslmode=disable`
2. `docker compose up -d`
3. Adicione uma regra de ingress no Cloudflare Tunnel pra `grafana.<dominio>` →
   `http://localhost:3001` (precisa editar `/etc/cloudflared/config.yml`, que é do root, e
   reiniciar o serviço `cloudflared`).
4. Faça login no Grafana e adicione dashboards via **Import**, usando os IDs da comunidade:
   - `1860` — Node Exporter Full
   - `19792` (ou `193`) — containers Docker/cAdvisor

## Limites de recurso

Todo container tem um `mem_limit` dimensionado pra uma VPS pequena (a stack inteira usa
~1.3 GB no pior caso). Ajuste se o host tiver mais folga.
