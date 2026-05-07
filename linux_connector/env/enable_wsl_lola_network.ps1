$ErrorActionPreference = "Continue"

$wslVmCreatorId = "{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}"
$lolaUdpPorts = @(7000, 19788, 19798, 17000, 17001)
$lolaUdpPortString = $lolaUdpPorts -join ","

Write-Host "Writing WSL NAT networking config..."
$config = @"
[wsl2]
networkingMode=nat
firewall=false
localhostForwarding=true
"@
Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value $config -Encoding ASCII

Write-Host "Adding Windows firewall rule for LoLa/WSL UDP..."
New-NetFirewallRule -DisplayName "Linux LoLa WSL UDP Probe" `
    -Direction Inbound `
    -Action Allow `
    -Protocol UDP `
    -LocalPort $lolaUdpPorts `
    -Profile Any `
    -ErrorAction SilentlyContinue | Out-Host

Write-Host "Relaxing Hyper-V firewall for WSL if supported..."
try {
    Set-NetFirewallHyperVVMSetting `
        -Name $wslVmCreatorId `
        -DefaultInboundAction Allow `
        -DefaultOutboundAction Allow `
        -LoopbackEnabled True `
        -AllowHostPolicyMerge True `
        -ErrorAction Stop | Out-Host
} catch {
    Write-Host "Set-NetFirewallHyperVVMSetting failed or needs a specific VM creator ID: $($_.Exception.Message)"
}

try {
    New-NetFirewallHyperVRule -Name "Linux LoLa WSL UDP Probe" `
        -DisplayName "Linux LoLa WSL UDP Probe" `
        -VMCreatorId $wslVmCreatorId `
        -Direction Inbound `
        -Action Allow `
        -Protocol UDP `
        -LocalPorts $lolaUdpPortString `
        -RemoteAddresses Any `
        -LocalAddresses Any `
        -ErrorAction Stop | Out-Host
} catch {
    Write-Host "New-NetFirewallHyperVRule failed: $($_.Exception.Message)"
}

Write-Host "Shutting down WSL to apply networking changes..."
wsl --shutdown
Write-Host "Done. Restart WSL and rerun the probe."
