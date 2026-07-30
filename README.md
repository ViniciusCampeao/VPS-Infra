# vps-infra

Como organizo minha VPS: vários apps Dockerizados independentes atrás de um Cloudflare Tunnel
(sem portas públicas abertas), além de uma stack de monitoramento e backup fora da VPS —
documentado aqui pra ficar reproduzível e não só conhecimento na minha cabeça.

- [Arquitetura](docs/architecture.md) — organização, rede, tunnel, gerenciamento de processos
- [Monitoramento](docs/monitoring.md) — Prometheus + Grafana + exporters
- [Backup](docs/backup.md) — restic → S3, o que é coberto, como restaurar

## Estrutura do repositório

```
monitoring/   stack docker-compose: Prometheus, Grafana, exporters, proxy com basic auth
backup/       script de backup restic + lista de exclusões
docs/         os docs linkados acima
```

## Stack

Ubuntu 24.04 · Docker / Docker Compose · Cloudflare Tunnel · Tailscale · Prometheus · Grafana ·
restic · Fail2Ban · Autoheal · PM2

## Nota sobre segredos

Nada neste repositório é uma credencial real. Os arquivos `.env.example` mostram o formato da
configuração; os `.env` reais com senhas/chaves de verdade ficam só na VPS e estão no `.gitignore`.
