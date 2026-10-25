
#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-$HOME/fastapi-app}"
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"

export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv not found. Run install_python_uv.sh first."
    exit 1
fi

mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Initialize only if this is not already a uv project
if [[ ! -f pyproject.toml ]]; then
    uv init --python "$PYTHON_VERSION"
fi

# Install FastAPI and its standard dependencies
uv add "fastapi[standard]"

# Create a sample app only if main.py does not already exist
if [[ ! -f main.py ]]; then
    cat > main.py <<'PYTHON'
from fastapi import FastAPI

app = FastAPI(
    title="My EC2 FastAPI Application",
    version="1.0.0",
)

@app.get("/")
def home():
    return {
        "message": "Hello from FastAPI on Amazon EC2!",
        "status": "success",
    }

@app.get("/health")
def health():
    return {"status": "healthy"}


PYTHON
fi

# Verify that the app imports correctly
uv run python -c "from main import app; print('FastAPI application imported successfully')"

echo "FastAPI setup completed."
echo "Application directory: $APP_DIR"
echo "To test: cd '$APP_DIR' && uv run uvicorn main:app --host 0.0.0.0 --port 8000"
