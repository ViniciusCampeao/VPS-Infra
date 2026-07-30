#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
set -a
source ./.env
set +a

TS=$(date +%F_%H-%M-%S)
DUMP_DIR="$HOME/backup/dumps"
mkdir -p "$DUMP_DIR"

RESTIC="docker run --rm -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY restic/restic:latest"

echo "[$TS] Gerando dump do Postgres (recompra_farma)..."
docker exec farma-postgres pg_dump -U farma -d recompra_farma -Fc -f /tmp/recompra_farma.dump
docker cp farma-postgres:/tmp/recompra_farma.dump "$DUMP_DIR/recompra_farma.dump"
docker exec farma-postgres rm -f /tmp/recompra_farma.dump

echo "[$TS] Gerando snapshot do Redis..."
docker exec farma-redis redis-cli BGSAVE >/dev/null
sleep 5

echo "[$TS] Garantindo que o repositório restic existe..."
$RESTIC snapshots >/dev/null 2>&1 || $RESTIC init

echo "[$TS] Rodando backup restic..."
docker run --rm \
  -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  -v "$DUMP_DIR":/data/pg-dumps:ro \
  -v recompra-farma_redis_data:/data/redis_data:ro \
  -v recompra-farma_evolution_instances:/data/evolution_instances:ro \
  -v "$HOME":/data/home:ro \
  -v "$(pwd)/restic-excludes.txt":/data/excludes.txt:ro \
  restic/restic:latest backup \
    /data/pg-dumps /data/redis_data /data/evolution_instances /data/home \
    --exclude-file=/data/excludes.txt \
    --host vpspk-1 \
    --tag daily

echo "[$TS] Removendo snapshots antigos (mantém 7 diários / 4 semanais / 6 mensais)..."
$RESTIC forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

echo "[$TS] Backup concluído com sucesso."
