#!/usr/bin/env bash
# Backup diário do banco (campanhas, contas conectadas, histórico de DMs).
# Guarda 7 dias em /opt/insta-automation-backups. Roda sozinho às 03:30 (cron).
set -euo pipefail
B=/opt/insta-automation-backups
mkdir -p "$B" && chmod 700 "$B"
cd /opt/insta-automation/deploy/aivacs
docker compose exec -T postgres pg_dump -U openreply openreply | gzip > "$B/openreply-$(date +%F).sql.gz"
find "$B" -name 'openreply-*.sql.gz' -mtime +7 -delete
echo "$(date -Is) backup ok"
