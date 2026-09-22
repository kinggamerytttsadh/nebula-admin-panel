#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="nebula-panel"
APP_DIR="${APP_DIR:-/opt/nebula-panel}"
APP_USER="${APP_USER:-nebula}"
PORT="${PORT:-3000}"
DOMAIN="${DOMAIN:-_}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@panel.local}"
ADMIN_NAME="${ADMIN_NAME:-Founder Admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
REPO_URL="${NEBULA_REPO_URL:-REPLACE_WITH_GITHUB_REPOSITORY_URL}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

say() { printf '\n\033[1;36m[Nebula]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[Error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "Run as root: sudo bash install.sh"
command -v apt-get >/dev/null 2>&1 || die "Only Ubuntu and Debian are supported."
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || die "PORT must be between 1 and 65535."

export DEBIAN_FRONTEND=noninteractive
say "Installing system dependencies"
apt-get update
apt-get install -y ca-certificates curl git nginx openssl build-essential python3 nodejs npm
node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if (( node_major < 18 )); then
  die "Node.js 18+ is required. Install a newer Node.js release, then rerun this installer."
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
  ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"
fi
JWT_SECRET="$(openssl rand -hex 48)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

say "Preparing application files"
if [[ -f "$SCRIPT_DIR/package.json" && -f "$SCRIPT_DIR/server.js" ]]; then
  cp -a "$SCRIPT_DIR/." "$TMP_DIR/app/"
else
  [[ "$REPO_URL" != "https://github.com/kinggamerytttsadh/nebula-admin-panel.git" ]] || die "Set NEBULA_REPO_URL to your GitHub repository URL before remote installation."
  git clone --depth 1 "$REPO_URL" "$TMP_DIR/app"
fi
rm -rf "$TMP_DIR/app/.git" "$TMP_DIR/app/node_modules" "$TMP_DIR/app/dist" "$TMP_DIR/app/nebula.sqlite" "$TMP_DIR/app/data"

id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR" "$APP_DIR/data"
find "$APP_DIR" -mindepth 1 -maxdepth 1 ! -name data -exec rm -rf {} +
cp -a "$TMP_DIR/app/." "$APP_DIR/"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

say "Installing Node.js packages and building panel"
cd "$APP_DIR"
runuser -u "$APP_USER" -- npm install --no-audit --no-fund
runuser -u "$APP_USER" -- npm run build

cat > /etc/nebula-panel.env <<EOF
NODE_ENV=production
HOST=127.0.0.1
PORT=$PORT
DB_PATH=$APP_DIR/data/nebula.sqlite
JWT_SECRET=$JWT_SECRET
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_NAME=$ADMIN_NAME
EOF
chmod 600 /etc/nebula-panel.env

cat > /etc/systemd/system/nebula-panel.service <<EOF
[Unit]
Description=Nebula X Admin Panel
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=/etc/nebula-panel.env
ExecStart=/usr/bin/node $APP_DIR/server.js
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR/data

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/nginx/sites-available/nebula-panel <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
ln -sfn /etc/nginx/sites-available/nebula-panel /etc/nginx/sites-enabled/nebula-panel
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl daemon-reload
systemctl enable --now nebula-panel nginx

sleep 2
curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null || {
  systemctl status nebula-panel --no-pager || true
  journalctl -u nebula-panel -n 50 --no-pager || true
  die "Panel did not pass its health check."
}

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ "$DOMAIN" == "_" ]]; then PANEL_URL="http://${HOST_IP:-SERVER_IP}"; else PANEL_URL="http://$DOMAIN"; fi

printf '\n\033[1;32mNebula X installed successfully.\033[0m\n'
printf 'URL: %s\nAdmin email: %s\nAdmin password: %s\n' "$PANEL_URL" "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
printf '\nSave this password now. Service: systemctl status nebula-panel\n'
