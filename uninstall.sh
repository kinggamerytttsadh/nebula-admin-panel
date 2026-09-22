#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${EUID} -eq 0 ]] || { echo "Run as root: sudo bash uninstall.sh" >&2; exit 1; }
read -r -p "Remove Nebula X panel and its database? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0
systemctl disable --now nebula-panel 2>/dev/null || true
rm -f /etc/systemd/system/nebula-panel.service /etc/nebula-panel.env
rm -f /etc/nginx/sites-enabled/nebula-panel /etc/nginx/sites-available/nebula-panel
rm -rf /opt/nebula-panel
id -u nebula >/dev/null 2>&1 && userdel nebula || true
systemctl daemon-reload
nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
echo "Nebula X has been removed."
