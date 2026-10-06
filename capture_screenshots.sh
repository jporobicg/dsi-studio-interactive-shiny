#!/bin/bash
# Simple screenshot capture using Chrome directly

ARTIFACTS_DIR="/cursor/stores/self/artifacts"
mkdir -p "$ARTIFACTS_DIR"

echo "=== DSI Studio Screenshot Capture ==="
echo ""
echo "Capturing screenshots with Chrome headless..."
echo ""

# Function to capture screenshot
capture() {
  local url=$1
  local width=$2
  local name=$3
  local output="${ARTIFACTS_DIR}/${name}_${width}px.png"
  
  echo "  Capturing $name at ${width}px..."
  /usr/local/bin/google-chrome \
    --headless \
    --disable-gpu \
    --no-sandbox \
    --disable-dev-shm-usage \
    --window-size=${width},1200 \
    --screenshot="$output" \
    "$url" 2>/dev/null
  
  if [ -f "$output" ]; then
    echo "    ✓ Saved: $(basename $output)"
    return 0
  else
    echo "    ✗ Failed"
    return 1
  fi
}

# Base URL
BASE_URL="http://localhost:43210"

# Capture main view at different widths
echo "1. Main View"
capture "$BASE_URL" 1440 "main_view"
sleep 2
capture "$BASE_URL" 400 "main_view"
sleep 2

echo ""
echo "=== Screenshot Capture Complete ===  "
echo ""
echo "Screenshots saved to: $ARTIFACTS_DIR"
ls -lh "$ARTIFACTS_DIR"

echo ""
echo "Screenshot paths:"
for f in "$ARTIFACTS_DIR"/*.png; do
  if [ -f "$f" ]; then
    echo "  - $f"
  fi
done
