# codex-setup.sh  –  run ONCE when the Codex container is born
set -euo pipefail

# ── 1. install Wine & helpers (only while net is up) ────────────────────────
apt-get update -y
DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  wine winbind xvfb unzip curl ca-certificates

# ── 2. create a 64-bit prefix INSIDE /opt so it survives later layers ───────
export WINEPREFIX=/opt/mt5-prefix
if [[ ! -d "$WINEPREFIX" ]]; then
  mkdir -p "$WINEPREFIX"
  wineboot -u >/dev/null 2>&1 || true
fi

# ── 3. download portable MT5 installer once and cache ----------------------
MT5=/opt/mt5setup.exe
if [[ ! -f "$MT5" ]]; then
  curl -L -o "$MT5" \
    https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
fi

# ── 4. silent-install MetaEditor if not yet present ------------------------
if [[ ! -f "$WINEPREFIX/drive_c/Platform/metaeditor64.exe" ]]; then
  wine "$MT5" /silent /dir="C:\\Platform" /components=Main,MetaEditor
fi

# ── 5. expose paths for later Bash sessions --------------------------------
echo "export WINEPREFIX=/opt/mt5-prefix"               >> /etc/profile.d/mt5.sh
echo "export METAEDITOR_EXE=/opt/mt5-prefix/drive_c/Platform/metaeditor64.exe" \
     >> /etc/profile.d/mt5.sh
