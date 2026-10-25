
#!/usr/bin/env bash
set -Eeuo pipefail

APP_USER="${APP_USER:-ec2-user}"
SERVICE_NAME="${SERVICE_NAME:-fastapi}"
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
APP_DIR="${APP_DIR:-$APP_HOME/fastapi-app}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if [[ -z "$APP_HOME" || ! -x "$APP_DIR/.venv/bin/uvicorn" ]]; then
    echo "ERROR: Application or Uvicorn not found in $APP_DIR"
    echo "Run setup_fastapi.sh first."
    exit 1
fi

if [[ ! -f "$APP_DIR/main.py" ]]; then
    echo "ERROR: $APP_DIR/main.py does not exist."
    exit 1
fi

# Generate the systemd service definition
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=FastAPI Application
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}

ExecStart=${APP_DIR}/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000

Restart=on-failure
RestartSec=5

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Load, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "Waiting for service startup..."
sleep 2

if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service is running successfully."
else
    echo "ERROR: Service failed to start. Recent logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    exit 1
fi

sudo systemctl status "$SERVICE_NAME" --no-pager
