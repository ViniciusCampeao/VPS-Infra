# Arquitetura

Uma única VPS Ubuntu 24.04 rodando vários projetos independentes e sem relação entre si, lado a
lado. Cada app é seu próprio projeto Docker Compose, com diretório, rede e ciclo de vida próprios
— não existe uma "plataforma" compartilhada, só convenções aplicadas de forma consistente em todos.

## Organização

```
~/
├── app-um/
│   └── docker-compose.yml     # um projeto, um compose file, uma rede
├── app-dois/
│   └── docker-compose.yml
├── monitoring/                # stack de monitoramento deste repo (ver docs/monitoring.md)
└── backup/                    # script de backup deste repo (ver docs/backup.md)
```

Cada stack de app:
- Publica as portas só em `127.0.0.1` — nada escuta em interface pública.
- Tem sua própria rede Docker, então containers de apps diferentes não conseguem se
  alcançar a não ser que sejam conectados explicitamente (o monitoramento é a exceção: seus
  exporters entram na rede interna de um app, só leitura, pra coletar métricas).
- Roda com `restart: unless-stopped` e, quando faz sentido, um bloco `healthcheck`.

## Exposição: Cloudflare Tunnel

Nenhuma porta de entrada fica aberta no firewall/provedor da VPS. O `cloudflared` roda como
serviço systemd e mantém uma conexão de saída com a Cloudflare; cada hostname público é mapeado
no `/etc/cloudflared/config.yml` para um `service: http://localhost:<porta>` (ou
`ssh://localhost:22` pra acesso via shell pelo tunnel). A Cloudflare termina o TLS e faz proxy
dos hostnames correspondentes através do tunnel até a porta local certa. Expor um novo serviço
significa só adicionar um par `hostname:`/`service:` nesse arquivo e reiniciar o `cloudflared` —
sem port-forwarding, sem expor IP público do app.

## Extras de rede

- **Tailscale**: VPN mesh entre essa VPS e os dispositivos pessoais, usada pra acesso direto
  (ex: SSH) que não precisa passar pelo tunnel público.
- **Fail2Ban**: bane IPs reincidentes tentando SSH.
- **Autoheal**: observa containers que declaram `healthcheck` e reinicia os que ficam
  unhealthy. Containers entram nesse esquema com a label `autoheal=true`.
- **Unattended Upgrades**: aplica patches de segurança no SO base automaticamente.

## Gerenciamento de processos

A maioria dos serviços é containerizada, mas alguns processos Node pequenos rodam direto no
**PM2** em vez de Docker, onde um container não valia a pena.

## Observabilidade e resiliência

- [Monitoramento](./monitoring.md): Prometheus + Grafana + exporters, coletando métricas do
  host e de apps específicos.
- [Backup](./backup.md): backup diário criptografado de bancos de dados, dados de apps e
  configuração, pra um object storage fora da VPS.
