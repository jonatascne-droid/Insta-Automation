#!/usr/bin/env bash
# AIVACS: tudo num contêiner só (EasyPanel ou qualquer painel com um serviço).
# 1) aplica as migrações do banco; 2) roda o painel (web), o worker (envia as
# DMs) e o cron (renova tokens) juntos. Se qualquer um parar, o contêiner sai
# e a plataforma reinicia tudo, em vez de ficar meio funcionando.
set -euo pipefail

npx --no-install prisma migrate deploy

export CRON_BASE_URL="${CRON_BASE_URL:-http://127.0.0.1:${PORT:-3000}}"
trap 'trap - TERM INT; kill 0' TERM INT

npm run --silent worker &
sh scripts/cron.sh &
npm run --silent start &

wait -n
echo "[aivacs-start] um dos processos parou; saindo para a plataforma reiniciar tudo" >&2
trap - TERM INT
kill 0 2>/dev/null || true
exit 1
