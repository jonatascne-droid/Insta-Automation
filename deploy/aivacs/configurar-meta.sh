#!/usr/bin/env bash
# Grava as chaves do app da Meta no .env e reinicia o app.
# Uso: sudo bash /opt/insta-automation/deploy/aivacs/configurar-meta.sh
set -euo pipefail
APP=/opt/insta-automation/deploy/aivacs
ENVF="$APP/.env"
[ "$(id -u)" -eq 0 ] || { echo "rode com sudo"; exit 1; }
[ -f "$ENVF" ] || { echo "rode o instalar.sh primeiro"; exit 1; }

ask()        { local v; read -r -p "$1: " v </dev/tty; printf '%s' "$v"; }
ask_secret() { local v; read -r -s -p "$1 (não aparece enquanto digita): " v </dev/tty; echo >&2; printf '%s' "$v"; }
setvar() {
  local k="$1" v="$2"
  [[ "$v" =~ ^[A-Za-z0-9._-]*$ ]] || { echo "valor inválido para $k"; exit 1; }
  if grep -q "^$k=" "$ENVF"; then sed -i "s|^$k=.*|$k=$v|" "$ENVF"; else echo "$k=$v" >> "$ENVF"; fi
}

echo "Painel da Meta → seu app → Instagram → Configuração da API com login do Instagram"
setvar INSTAGRAM_APP_ID "$(ask 'ID do app do Instagram (número)')"
setvar INSTAGRAM_APP_SECRET "$(ask_secret 'Chave secreta do app do Instagram')"
echo "Painel da Meta → Configurações do app → Básico → Chave secreta do app"
setvar FACEBOOK_APP_SECRET "$(ask_secret 'Chave secreta do app (Facebook)')"

cd "$APP" && docker compose up -d --force-recreate web worker cron
echo "Pronto. Chaves gravadas e app reiniciado."
