#!/usr/bin/env bash
# Instalador do Insta Automation (AIVACS) num servidor Ubuntu novo
# (Oracle Cloud "Always Free", ARM Ampere A1 recomendado).
#
# Uso, conectado ao servidor por SSH:
#   curl -fsSL https://raw.githubusercontent.com/jonatascne-droid/Insta-Automation/main/deploy/aivacs/instalar.sh -o instalar.sh && bash instalar.sh
#
# Pode rodar de novo sem medo: o que já existe é mantido (o .env não é recriado).
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/jonatascne-droid/Insta-Automation.git}"
DIR=/opt/insta-automation
APP="$DIR/deploy/aivacs"
ENVF="$APP/.env"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[atenção] %s\033[0m\n' "$*"; }
ask()  { local v; read -r -p "$1${2:+ [$2]}: " v </dev/tty; printf '%s' "${v:-${2:-}}"; }
ask_secret() { local v; read -r -s -p "$1: " v </dev/tty; echo >&2; printf '%s' "$v"; }
urlenc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }

[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"

say "Conferindo se o servidor já usa as portas 80/443 (sites, n8n, painéis...)"
# Antes de instalar qualquer coisa: se outro programa já atende nessas portas,
# para aqui sem mudar nada, para não derrubar o que já existe no servidor.
porta_ocupada() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
OCUPADAS=""
for p in 80 443; do porta_ocupada "$p" && OCUPADAS="$OCUPADAS $p"; done
if [ -n "$OCUPADAS" ] && ! $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -qx insta-automation-caddy-1; then
  warn "Porta(s)$OCUPADAS já em uso neste servidor. Quem está usando:"
  $SUDO docker ps --format '  contêiner {{.Names}} ({{.Image}}) {{.Ports}}' 2>/dev/null | grep -E ':(80|443)->' || true
  $SUDO ss -ltnpH '( sport = :80 or sport = :443 )' 2>/dev/null | sed 's/^/  /' || true
  echo
  echo "Nada foi instalado nem alterado. Mande este texto para o Claude: ele ajusta a"
  echo "instalação para funcionar junto com o que já existe."
  exit 1
fi
echo "livres, ok"

say "1/7 Memória de troca (evita falta de memória ao compilar)"
if [ "$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)" -lt 6000 ] && ! swapon --show | grep -q .; then
  $SUDO fallocate -l 4G /swapfile && $SUDO chmod 600 /swapfile && $SUDO mkswap /swapfile >/dev/null && $SUDO swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
  echo "swap de 4 GB criado"
else
  echo "ok"
fi

say "2/7 Pacotes do sistema e Docker"
$SUDO apt-get update -qq
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates python3 openssl >/dev/null
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | $SUDO sh >/dev/null
fi
$SUDO systemctl enable --now docker >/dev/null 2>&1 || true
$SUDO docker compose version

say "3/7 Firewall do sistema (portas 80 e 443)"
if command -v ufw >/dev/null && $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
  $SUDO ufw allow 80/tcp >/dev/null && $SUDO ufw allow 443/tcp >/dev/null
  echo "liberadas no ufw"
elif $SUDO iptables -S INPUT 2>/dev/null | grep -qE -- '-j (REJECT|DROP)'; then
  # Imagens Ubuntu da Oracle bloqueiam tudo menos SSH.
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iptables-persistent >/dev/null
  for p in 80 443; do
    $SUDO iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || $SUDO iptables -I INPUT 1 -p tcp --dport "$p" -j ACCEPT
  done
  $SUDO netfilter-persistent save >/dev/null 2>&1 || true
  echo "liberadas no iptables (na Oracle, libere também na Security List, passo do guia)"
else
  echo "o firewall do sistema não bloqueia, ok"
fi

say "4/7 Baixando o código"
if [ -d "$DIR/.git" ]; then
  $SUDO git -c safe.directory="$DIR" -C "$DIR" pull -q --ff-only
else
  $SUDO git clone -q "$REPO_URL" "$DIR"
fi
$SUDO git -c safe.directory="$DIR" -C "$DIR" log -1 --format='versão %h de %cs'

say "5/7 Configuração"
if $SUDO test -f "$ENVF"; then
  echo "já existe $ENVF, mantendo"
else
  echo "Responda as perguntas (Enter aceita o valor entre colchetes)."
  DOMAIN=$(ask "Endereço do app (subdomínio apontado para este servidor)" "auto.aivacs.online")
  LOGIN=$(ask "E-mail(s) que podem entrar no painel, separados por vírgula")
  echo
  echo "Envio do e-mail de login (link mágico). Use o e-mail da AIVACS ou um Gmail com senha de app."
  SMTP_HOST=$(ask "Servidor SMTP" "smtp.gmail.com")
  SMTP_PORT=$(ask "Porta SMTP (465 = SSL, 587 = STARTTLS)" "465")
  SMTP_USER=$(ask "Usuário SMTP (o e-mail completo)")
  SMTP_PASS=$(ask_secret "Senha SMTP (não aparece enquanto digita)")
  FROM_ADDR=$(ask "Remetente" "$SMTP_USER")
  [ "$SMTP_PORT" = "465" ] && SCHEME=smtps || SCHEME=smtp
  EMAIL_SERVER="$SCHEME://$(urlenc "$SMTP_USER"):$(urlenc "$SMTP_PASS")@$SMTP_HOST:$SMTP_PORT"
  umask 077
  cat > /tmp/insta-automation.env <<EOF
# Gerado por instalar.sh em $(date -I). Secreto: não compartilhe nem commite.
DOMAIN=$DOMAIN
NEXTAUTH_URL=https://$DOMAIN
POSTGRES_PASSWORD=$(openssl rand -hex 24)
NEXTAUTH_SECRET=$(openssl rand -base64 32 | tr -d '\n')
CRON_SECRET=$(openssl rand -hex 24)
ENCRYPTION_KEY=$(openssl rand -hex 32)
WEBHOOK_VERIFY_TOKEN=$(openssl rand -hex 16)
EMAIL_SERVER='$EMAIL_SERVER'
EMAIL_FROM='AIVACS <$FROM_ADDR>'
ALLOWED_EMAILS=$(printf '%s' "$LOGIN" | tr -d ' ')
META_GRAPH_API_VERSION=v25.0
# Preenchidos depois com: sudo bash $APP/configurar-meta.sh
INSTAGRAM_APP_ID=
INSTAGRAM_APP_SECRET=
FACEBOOK_APP_SECRET=
EOF
  $SUDO install -m 600 /tmp/insta-automation.env "$ENVF" && rm -f /tmp/insta-automation.env
  echo "configuração salva em $ENVF"
fi
DOMAIN=$($SUDO grep '^DOMAIN=' "$ENVF" | cut -d= -f2)
MYIP=$(curl -fsS https://api.ipify.org || true)
DNSIP=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}' || true)
if [ -n "$MYIP" ] && [ "$MYIP" != "$DNSIP" ]; then
  warn "$DOMAIN aponta para '${DNSIP:-nada}', mas este servidor é $MYIP. Crie o registro A no DNS; o HTTPS começa a funcionar sozinho quando o DNS propagar."
fi

say "6/7 Compilando e iniciando (a primeira vez leva de 5 a 15 minutos)"
cd "$APP"
$SUDO docker compose up -d --build --remove-orphans

say "7/7 Atualização automática e backup diário"
$SUDO chmod +x "$APP"/*.sh
$SUDO tee /etc/cron.d/insta-automation >/dev/null <<EOF
*/10 * * * * root $APP/atualizar.sh >> /var/log/insta-automation-update.log 2>&1
30 3 * * * root $APP/backup.sh >> /var/log/insta-automation-backup.log 2>&1
EOF
echo "o servidor busca atualizações do GitHub a cada 10 minutos; backup do banco às 03:30"

printf 'Esperando o app responder em https://%s ' "$DOMAIN"
for _ in $(seq 1 36); do
  if curl -fsS -o /dev/null "https://$DOMAIN/login" 2>/dev/null; then OK=1; break; fi
  printf '.'; sleep 5
done
echo
TOKEN=$($SUDO grep '^WEBHOOK_VERIFY_TOKEN=' "$ENVF" | cut -d= -f2)
cat <<EOF

$( [ "${OK:-}" = 1 ] && echo "PRONTO: https://$DOMAIN está no ar." || echo "O app ainda não respondeu por HTTPS. Confira o DNS e as portas 80/443 na Oracle; ele tenta sozinho de novo.")

Para configurar o app da Meta você vai precisar destes dados:
  URL de redirecionamento OAuth:  https://$DOMAIN/api/instagram/callback
  URL de callback do webhook:     https://$DOMAIN/api/webhook
  Token de verificação:           $TOKEN

Depois de criar o app da Meta, rode:
  sudo bash $APP/configurar-meta.sh
EOF
