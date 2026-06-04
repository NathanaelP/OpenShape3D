#!/usr/bin/env bash
# Bootstrap Qt (via aqtinstall) and check for vcpkg.
# Run once from the repo root: bash scripts/setup-deps.sh
# After this, set the two env vars printed at the end and use cmake --preset.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Config — bump these when upgrading ────────────────────────────────────────
QT_VERSION="6.7.3"
QT_BASE_DIR="$REPO_ROOT/deps/Qt"

# ── Detect OS ─────────────────────────────────────────────────────────────────
case "$(uname -s)" in
    Linux*)
        OS=linux
        QT_HOST=linux
        QT_ARCH=gcc_64
        CMAKE_PRESET=linux-debug
        ;;
    Darwin*)
        OS=macos
        QT_HOST=mac
        QT_ARCH=clang_64
        CMAKE_PRESET=macos-debug
        ;;
    *)
        echo "Unsupported OS: $(uname -s). Use scripts/setup-deps.ps1 on Windows."
        exit 1
        ;;
esac

QT_INSTALL_DIR="$QT_BASE_DIR/$QT_VERSION/$QT_ARCH"

echo "========================================"
echo " OpenShape dependency setup"
echo " OS: $OS  |  Qt: $QT_VERSION/$QT_ARCH"
echo "========================================"
echo ""

# ── Qt via aqtinstall ─────────────────────────────────────────────────────────
if [ -d "$QT_INSTALL_DIR/lib/cmake/Qt6" ]; then
    echo "[Qt] Already installed at $QT_INSTALL_DIR — skipping download."
else
    echo "[Qt] Installing / upgrading aqtinstall..."
    python3 -m pip install --upgrade aqtinstall --quiet

    echo "[Qt] Downloading Qt $QT_VERSION for $QT_HOST / $QT_ARCH..."
    mkdir -p "$QT_BASE_DIR"
    python3 -m aqt install-qt \
        "$QT_HOST" desktop "$QT_VERSION" "$QT_ARCH" \
        --outputdir "$QT_BASE_DIR"
    echo "[Qt] Done."
fi

echo ""

# ── vcpkg ─────────────────────────────────────────────────────────────────────
echo "[vcpkg] Checking VCPKG_ROOT..."

if [ -n "${VCPKG_ROOT:-}" ] && [ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]; then
    echo "[vcpkg] Found at VCPKG_ROOT=$VCPKG_ROOT"
else
    DEFAULT_VCPKG="$HOME/.vcpkg"
    echo ""
    echo "[vcpkg] VCPKG_ROOT is not set or vcpkg is not bootstrapped."
    echo "  Run the following once to install vcpkg:"
    echo ""
    echo "    git clone https://github.com/microsoft/vcpkg.git \"$DEFAULT_VCPKG\""
    echo "    \"$DEFAULT_VCPKG/bootstrap-vcpkg.sh\""
    echo "    export VCPKG_ROOT=\"$DEFAULT_VCPKG\""
    echo ""
    echo "  Then re-run this script."
    echo ""
    # Don't exit — Qt is already done; let the user fix vcpkg separately.
fi

# ── vcpkg baseline note ───────────────────────────────────────────────────────
# vcpkg.json does not currently contain a builtin-baseline, meaning vcpkg
# uses the latest registry on first install. To lock the baseline for
# reproducible builds, run once after vcpkg is set up:
#
#   cd "$REPO_ROOT"
#   vcpkg x-update-baseline --add-initial-baseline
#
# Commit the resulting change to vcpkg.json.

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Next steps"
echo "========================================"
echo ""
echo "1. Ensure vcpkg is installed and bootstrapped (see above if not)."
echo ""
echo "2. Export these two variables (add to ~/.bashrc or ~/.zshrc to make"
echo "   them permanent):"
echo ""
echo "     export VCPKG_ROOT=\"\$HOME/.vcpkg\""
echo "     export QT_DIR=\"$QT_INSTALL_DIR\""
echo ""
echo "3. Configure and build:"
echo ""
echo "     cmake --preset $CMAKE_PRESET"
echo "     cmake --build build"
echo ""
echo "   On the first run vcpkg will compile OCCT — this takes 20-40 min."
echo "   Subsequent runs use the vcpkg binary cache and are fast."
echo ""
