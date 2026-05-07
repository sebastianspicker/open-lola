param(
    [string]$Distro = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"

function Enable-FeatureIfNeeded {
    param([string]$FeatureName)
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart | Out-Host
    } else {
        Write-Host "$FeatureName already enabled"
    }
}

Write-Host "Enabling WSL Windows features..."
Enable-FeatureIfNeeded -FeatureName "Microsoft-Windows-Subsystem-Linux"
Enable-FeatureIfNeeded -FeatureName "VirtualMachinePlatform"

Write-Host "Setting WSL2 as default..."
wsl --set-default-version 2

Write-Host "Installing $Distro..."
wsl --install -d $Distro --no-launch

Write-Host ""
Write-Host "WSL installation requested."
Write-Host "If Windows reports a reboot is required, reboot, then run:"
Write-Host "  wsl -d $Distro"
Write-Host "After Ubuntu initializes, run from the repo root:"
Write-Host "  ./linux_connector/env/wsl_setup.sh"
