#!/usr/bin/env bash
# Gera o bloco de variáveis para colar na aba "Environment" do app no EasyPanel.
# Cria as senhas internas na hora (no próprio servidor) e pergunta o resto.
#
# Uso, no terminal do VPS (hPanel → VPS → Web console):
#   curl -fsSL https://raw.githubusercontent.com/jonatascne-droid/Insta-Automation/main/deploy/aivacs/easypanel-env.sh -o easypanel-env.sh && bash easypanel-env.sh
set -euo pipefail

ask()        { local v; read -r -p "$1${2:+ [$2]}: " v </dev/tty; printf '%s' "${v:-${2:-}}"; }
ask_secret() { local v; read -r -s -p "$1 (não aparece enquanto digita): " v </dev/tty; echo >&2; printf '%s' "$v"; }
urlenc()     { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }

echo "Responda as perguntas (Enter aceita o valor entre colchetes)."
echo
DATABASE_URL=$(ask "Cole a 'Internal Connection URL' do Postgres (EasyPanel → serviço db)")
REDIS_URL=$(ask "Cole a 'Internal Connection URL' do Redis (EasyPanel → serviço redis)")
DOMAIN=$(ask "Endereço do app" "auto.aivacs.online")
LOGIN=$(ask "E-mail(s) que podem entrar no painel, separados por vírgula")
echo
echo "E-mail que envia o link de login (Gmail com senha de app, ou outro SMTP):"
SMTP_HOST=$(ask "Servidor SMTP" "smtp.gmail.com")
SMTP_PORT=$(ask "Porta SMTP (465 = SSL, 587 = STARTTLS)" "465")
SMTP_USER=$(ask "Usuário SMTP (o e-mail completo)")
SMTP_PASS=$(ask_secret "Senha SMTP")
FROM_ADDR=$(ask "Remetente" "$SMTP_USER")
[ "$SMTP_PORT" = "465" ] && SCHEME=smtps || SCHEME=smtp

cat <<EOF

=============== COPIE DAQUI PARA BAIXO (até a linha de =) ===============
DATABASE_URL=$DATABASE_URL
REDIS_URL=$REDIS_URL
NEXTAUTH_URL=https://$DOMAIN
NEXTAUTH_SECRET=$(openssl rand -hex 32)
CRON_SECRET=$(openssl rand -hex 24)
ENCRYPTION_KEY=$(openssl rand -hex 32)
WEBHOOK_VERIFY_TOKEN=$(openssl rand -hex 16)
EMAIL_SERVER=$SCHEME://$(urlenc "$SMTP_USER"):$(urlenc "$SMTP_PASS")@$SMTP_HOST:$SMTP_PORT
EMAIL_FROM=AIVACS <$FROM_ADDR>
ALLOWED_EMAILS=$(printf '%s' "$LOGIN" | tr -d ' ')
META_GRAPH_API_VERSION=v25.0
NODE_ENV=production
INSTAGRAM_APP_ID=
INSTAGRAM_APP_SECRET=
FACEBOOK_APP_SECRET=
==========================================================================

Guarde uma cópia desse bloco num lugar seguro (ex.: nota protegida). Se o
ENCRYPTION_KEY se perder, as contas do Instagram precisam ser reconectadas.
EOF
