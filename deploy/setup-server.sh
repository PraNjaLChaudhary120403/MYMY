#!/usr/bin/env bash
# One-time setup for a fresh Ubuntu EC2 instance. Run it as the login user
# (e.g. "ubuntu"), not as root:  bash setup-server.sh
# Installs Node.js and Nginx, and registers the app as a systemd service.
set -euo pipefail

APP_DIR=/var/www/mymy
APP_USER="$USER"

curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs nginx

sudo mkdir -p "$APP_DIR/releases" "$APP_DIR/shared"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
# Runtime environment variables go here, one KEY=value per line.
touch "$APP_DIR/shared/.env"
chmod 600 "$APP_DIR/shared/.env"

sudo tee /etc/systemd/system/mymy.service > /dev/null <<EOF
[Unit]
Description=mymy Next.js app
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$APP_DIR/current
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOSTNAME=127.0.0.1
EnvironmentFile=-$APP_DIR/shared/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/nginx/sites-available/mymy > /dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -sfn /etc/nginx/sites-available/mymy /etc/nginx/sites-enabled/mymy
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

sudo systemctl daemon-reload
sudo systemctl enable mymy

echo "Server ready. The app starts on the first deploy from GitHub Actions."
