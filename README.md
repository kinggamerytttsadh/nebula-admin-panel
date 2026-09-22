# Nebula X Admin Panel

Node.js, React, Express and SQLite admin panel for Ubuntu/Debian.

## Features currently implemented

- JWT login and user registration API
- Admin/user roles
- Create and delete server records
- Start, stop and restart state actions
- User and ticket administration
- Audit log and dashboard statistics
- Responsive React interface
- SQLite persistence
- systemd service and Nginx reverse proxy installer

> **Important:** Console, Files, Billing and Settings are interface placeholders. Start/stop/restart currently update SQLite state only; they do not control real game-server processes. A node/daemon integration is required for real machine control.

## Supported systems

- Ubuntu
- Debian
- Node.js 18 or newer

## Local development

```bash
npm install
npm run build
npm start
```

Default local login (development only):

- Email: `admin@panel.local`
- Password: `admin123`

## Server installation

Clone the repository and run:

```bash
git clone YOUR_GITHUB_REPOSITORY_URL nebula-panel
cd nebula-panel
sudo bash install.sh
```

Optional settings:

```bash
sudo DOMAIN=panel.example.com \
  ADMIN_EMAIL=you@example.com \
  ADMIN_PASSWORD='use-a-strong-password' \
  bash install.sh
```

For remote one-line installation, replace `REPLACE_WITH_GITHUB_REPOSITORY_URL` inside `install.sh` after publishing the repository, then use:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPOSITORY/main/install.sh)
```

The installer:

1. Installs system packages.
2. Creates a restricted `nebula` service account.
3. Generates a random JWT secret and admin password when none is supplied.
4. Builds the React frontend.
5. Creates and starts a hardened systemd service.
6. Configures Nginx on port 80.
7. Runs an application health check.

## Operations

```bash
systemctl status nebula-panel
journalctl -u nebula-panel -f
systemctl restart nebula-panel
```

Runtime configuration is stored in `/etc/nebula-panel.env`. Application data is stored in `/opt/nebula-panel/data/nebula.sqlite`.

## HTTPS

Point the domain's DNS record to the server, install Certbot, and issue an Nginx certificate:

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d panel.example.com
```

## Uninstall

```bash
sudo bash uninstall.sh
```
