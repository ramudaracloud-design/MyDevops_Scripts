
#!/usr/bin/env bash
set -Eeuo pipefail

# Amazon Linux 2023 + FastAPI systemd service
APP_USER="${APP_USER:-ec2-user}"
SERVICE_NAME="${SERVICE_NAME:-fastapi}"
NGINX_CONF="/etc/nginx/conf.d/fastapi.conf"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Ask for the domain
# read -r -p "Enter your API domain (e.g. api.example.com): " DOMAIN

read -r -p "Enter your EC2 public IPv4 address: " DOMAIN

if [[ -z "$DOMAIN" || "$DOMAIN" == *"://"* || "$DOMAIN" == */* ]]; then
    echo "ERROR: Enter a domain name only, without http:// or a path."
    exit 1
fi

# Find the application user's home directory
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
APP_DIR="${APP_DIR:-$APP_HOME/fastapi-app}"

if [[ -z "$APP_HOME" || ! -x "$APP_DIR/.venv/bin/uvicorn" ]]; then
    echo "ERROR: FastAPI/Uvicorn not found in $APP_DIR"
    exit 1
fi

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "ERROR: systemd service not found: $SERVICE_FILE"
    exit 1
fi

echo "1. Installing Nginx..."
sudo dnf install -y nginx

echo "2. Configuring FastAPI to listen only on localhost..."

# Back up the existing service definition
sudo cp -n "$SERVICE_FILE" "${SERVICE_FILE}.bak"

# Change Uvicorn's host binding from 0.0.0.0 to 127.0.0.1
if grep -Eq -- '--host[[:space:]]+0\.0\.0\.0' "$SERVICE_FILE"; then
    sudo sed -i -E \
        's/--host[[:space:]]+0\.0\.0\.0/--host 127.0.0.1/' \
        "$SERVICE_FILE"
elif ! grep -Eq -- '--host[[:space:]]+127\.0\.0\.1' "$SERVICE_FILE"; then
    echo "ERROR: Could not find a supported Uvicorn --host setting."
    echo "Check $SERVICE_FILE and update it manually."
    exit 1
fi

sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"

if ! sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "ERROR: FastAPI did not start. Recent logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    exit 1
fi

echo "3. Creating Nginx reverse proxy configuration..."

sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    access_log /var/log/nginx/fastapi_access.log;
    error_log  /var/log/nginx/fastapi_error.log;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
}
EOF

echo "4. Validating Nginx configuration..."
if ! sudo nginx -t; then
    echo "ERROR: Nginx configuration validation failed."
    exit 1
fi

echo "5. Enabling and restarting Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

if ! sudo systemctl is-active --quiet nginx; then
    echo "ERROR: Nginx did not start. Recent logs:"
    sudo journalctl -u nginx -n 50 --no-pager
    exit 1
fi

echo
echo "Nginx reverse proxy setup completed."
echo "Domain: http://${DOMAIN}"
echo "FastAPI upstream: http://127.0.0.1:8000"
echo
echo "Check services:"
sudo systemctl --no-pager --full status nginx
sudo systemctl --no-pager --full status "$SERVICE_NAME"

echo
echo "Local proxy test:"
curl --fail --show-error \
    -H "Host: ${DOMAIN}" http://127.0.0.1/health
echo
echo
echo "IMPORTANT: Configure DNS and EC2 Security Group as described below."
