# Compatibility entry point for the canonical WSL network configuration script.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE ".wslconfig"),
    [string]$RuleName = "Linux LoLa WSL UDP Probe",
    [int[]]$UdpPorts = @(7000, 19788, 19798, 17000, 17001),
    [string]$FirewallProfile = "Private",
    [string]$InterfaceAlias = "vEthernet (WSL)",
    [string]$WslVmCreatorId = "{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}",
    [switch]$SkipWslShutdown
)

$canonicalScript = Join-Path $PSScriptRoot "..\deployment\wsl\enable_wsl_lola_network.ps1"
& $canonicalScript @PSBoundParameters
