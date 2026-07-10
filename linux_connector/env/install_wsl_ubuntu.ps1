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
        Write-Information "$FeatureName already enabled" -InformationAction Continue
    }
}

Write-Information "Enabling WSL Windows features..." -InformationAction Continue
Enable-FeatureIfNeeded -FeatureName "Microsoft-Windows-Subsystem-Linux"
Enable-FeatureIfNeeded -FeatureName "VirtualMachinePlatform"

Write-Information "Setting WSL2 as default..." -InformationAction Continue
wsl --set-default-version 2

Write-Information "Installing $Distro..." -InformationAction Continue
wsl --install -d $Distro --no-launch

Write-Information "" -InformationAction Continue
Write-Information "WSL installation requested." -InformationAction Continue
Write-Information "If Windows reports a reboot is required, reboot, then run:" -InformationAction Continue
Write-Information "  wsl -d $Distro" -InformationAction Continue
Write-Information "After Ubuntu initializes, run from the repo root:" -InformationAction Continue
Write-Information "  ./linux_connector/env/wsl_setup.sh" -InformationAction Continue
