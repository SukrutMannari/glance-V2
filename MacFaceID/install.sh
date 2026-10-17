#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "======================================================"
echo "      Glance-V2 / MacFaceID Engine Setup             "
echo "======================================================"

# Check for Python 3
PYTHON_BIN=""
for py in python3 /usr/local/bin/python3 /opt/homebrew/bin/python3; do
    if command -v "$py" >/dev/null 2>&1; then
        PYTHON_BIN="$py"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "Error: Python 3 was not found on your system."
    echo "Please install Python 3 via Homebrew or https://python.org."
    exit 1
fi

echo "[+] Using Python: $($PYTHON_BIN --version) ($PYTHON_BIN)"

# Create virtual environment if not present
if [ ! -d "venv" ]; then
    echo "[+] Creating virtual environment in ./venv..."
    "$PYTHON_BIN" -m venv venv
else
    echo "[+] Existing virtual environment detected."
fi

# Upgrade pip and install requirements
echo "[+] Installing OpenCV and NumPy dependencies..."
./venv/bin/pip install --upgrade pip --quiet
./venv/bin/pip install -r requirements.txt --quiet

# Download models
echo "[+] Ensuring YuNet & SFace biometrics models are downloaded..."
./venv/bin/python3 download_models.py

# Create templates directory
mkdir -p templates
mkdir -p "$HOME/.macfaceid/templates"
mkdir -p "$HOME/.macfaceid/models"
cp -n models/*.onnx "$HOME/.macfaceid/models/" 2>/dev/null || true

echo ""
echo "======================================================"
echo " Setup complete!"
echo " Next step: Enroll your face by running:"
echo "   ./venv/bin/python3 enroll_face.py"
echo "======================================================"
