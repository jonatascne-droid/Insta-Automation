#!/usr/bin/env bash
# Busca a versão nova no GitHub e, se houver, recompila e reinicia.
# Roda sozinho a cada 10 minutos (cron). Manual: sudo bash atualizar.sh --forcar
set -euo pipefail
DIR=/opt/insta-automation
G=(git -c safe.directory="$DIR" -C "$DIR")

exec 9>/var/lock/insta-automation-update.lock
flock -n 9 || exit 0

"${G[@]}" fetch -q origin main
if [ "$("${G[@]}" rev-parse HEAD)" != "$("${G[@]}" rev-parse origin/main)" ] || [ "${1:-}" = "--forcar" ]; then
  "${G[@]}" reset -q --hard origin/main
  cd "$DIR/deploy/aivacs"
  docker compose up -d --build --remove-orphans
  docker image prune -f >/dev/null
  echo "$(date -Is) atualizado para $("${G[@]}" rev-parse --short HEAD)"
fi
