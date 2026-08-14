# Compatibility entry point for the canonical WSL installation script.
param(
    [string]$Distro = "Ubuntu-24.04"
)

$canonicalScript = Join-Path $PSScriptRoot "..\deployment\wsl\install_wsl_ubuntu.ps1"
& $canonicalScript @PSBoundParameters
