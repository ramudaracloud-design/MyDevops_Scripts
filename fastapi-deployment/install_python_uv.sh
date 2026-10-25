
#!/usr/bin/env bash
set -Eeuo pipefail

# Amazon Linux 2023: install prerequisites
sudo dnf install -y curl ca-certificates

# Install uv for the current user
curl -LsSf https://astral.sh/uv/install.sh | sh

# Make uv available in this script and future commands
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv installation failed or uv is not in PATH."
    exit 1
fi

echo "Installed uv:"
uv --version

# Choose the Python version; override when running the script
PYTHON_VERSION="${PYTHON_VERSION:-3.15}"

echo "Installing Python ${PYTHON_VERSION}..."
uv python install "$PYTHON_VERSION"

echo "Available Python versions:"
uv python list

echo "Python and uv setup completed successfully."
