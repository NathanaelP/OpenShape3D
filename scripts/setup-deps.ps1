# Bootstrap Qt (via aqtinstall) and check for vcpkg on Windows.
# Run once from the repo root: .\scripts\setup-deps.ps1
# After this, set the two env vars printed at the end and use cmake --preset.
#
# Prerequisites: Python 3 on PATH, Ninja, CMake, Visual Studio 2022 (C++ workload).
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$QtVersion  = "6.7.3"
$QtArch     = "win64_msvc2022_64"
$QtHost     = "windows"
$QtBaseDir  = Join-Path $RepoRoot "deps\Qt"
$QtInstallDir = Join-Path $QtBaseDir "$QtVersion\$QtArch"

Write-Host ""
Write-Host "========================================"
Write-Host " OpenShape dependency setup (Windows)"
Write-Host " Qt: $QtVersion / $QtArch"
Write-Host "========================================"
Write-Host ""

# ── Qt via aqtinstall ─────────────────────────────────────────────────────────
$QtCmakeDir = Join-Path $QtInstallDir "lib\cmake\Qt6"
if (Test-Path $QtCmakeDir) {
    Write-Host "[Qt] Already installed at $QtInstallDir — skipping download."
} else {
    Write-Host "[Qt] Installing / upgrading aqtinstall..."
    python -m pip install --upgrade aqtinstall --quiet

    Write-Host "[Qt] Downloading Qt $QtVersion for $QtHost / $QtArch..."
    New-Item -ItemType Directory -Force -Path $QtBaseDir | Out-Null
    python -m aqt install-qt `
        $QtHost desktop $QtVersion $QtArch `
        --outputdir $QtBaseDir
    Write-Host "[Qt] Done."
}

Write-Host ""

# ── vcpkg ─────────────────────────────────────────────────────────────────────
Write-Host "[vcpkg] Checking VCPKG_ROOT..."
$VcpkgRoot = $env:VCPKG_ROOT

if ($VcpkgRoot -and (Test-Path (Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"))) {
    Write-Host "[vcpkg] Found at VCPKG_ROOT=$VcpkgRoot"
} else {
    $DefaultVcpkg = Join-Path $env:USERPROFILE ".vcpkg"
    Write-Host ""
    Write-Host "[vcpkg] VCPKG_ROOT is not set or vcpkg is not bootstrapped."
    Write-Host "  Run the following once to install vcpkg:"
    Write-Host ""
    Write-Host "    git clone https://github.com/microsoft/vcpkg.git `"$DefaultVcpkg`""
    Write-Host "    & `"$DefaultVcpkg\bootstrap-vcpkg.bat`""
    Write-Host "    `$env:VCPKG_ROOT = `"$DefaultVcpkg`""
    Write-Host "    [System.Environment]::SetEnvironmentVariable('VCPKG_ROOT','$DefaultVcpkg','User')"
    Write-Host ""
    Write-Host "  Then re-run this script."
    Write-Host ""
}

# ── vcpkg baseline note ───────────────────────────────────────────────────────
# After vcpkg is set up, lock the registry baseline for reproducible builds:
#
#   cd <repo-root>
#   vcpkg x-update-baseline --add-initial-baseline
#
# Commit the resulting change to vcpkg.json.

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================"
Write-Host " Next steps"
Write-Host "========================================"
Write-Host ""
Write-Host "1. Ensure vcpkg is installed and bootstrapped (see above if not)."
Write-Host ""
Write-Host "2. Set these variables (run once per shell, or add to your profile):"
Write-Host ""
Write-Host "     `$env:VCPKG_ROOT = `"$env:USERPROFILE\.vcpkg`""
Write-Host "     `$env:QT_DIR     = `"$QtInstallDir`""
Write-Host ""
Write-Host "3. Configure and build:"
Write-Host ""
Write-Host "     cmake --preset windows-debug"
Write-Host "     cmake --build build"
Write-Host ""
Write-Host "   On the first run vcpkg will compile OCCT — this takes 20-60 min."
Write-Host "   Subsequent runs use the vcpkg binary cache and are fast."
Write-Host ""
