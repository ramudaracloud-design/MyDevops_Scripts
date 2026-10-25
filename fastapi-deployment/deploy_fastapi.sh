
#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-$HOME/fastapi-app}"
SERVICE_NAME="${SERVICE_NAME:-fastapi}"

export PATH="$HOME/.local/bin:$PATH"

cd "$APP_DIR"

if [[ ! -f pyproject.toml ]]; then
    echo "ERROR: pyproject.toml not found in $APP_DIR"
    exit 1
fi

echo "Installing/synchronizing project dependencies..."
uv sync

echo "Restarting ${SERVICE_NAME}..."
sudo systemctl restart "$SERVICE_NAME"

echo "Checking service status..."
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Deployment completed successfully."
    sudo systemctl status "$SERVICE_NAME" --no-pager
else
    echo "ERROR: Deployment failed. Recent logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    exit 1
fi
