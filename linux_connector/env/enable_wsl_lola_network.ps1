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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Merge-WslConfigText {
    param(
        [string[]]$ExistingLines
    )

    $requiredSettings = [ordered]@{
        networkingMode = "nat"
        firewall = "false"
        localhostForwarding = "true"
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    $inWsl2 = $false
    $sawWsl2 = $false
    $seenKeys = @{}

    function Add-MissingWsl2Settings {
        foreach ($key in $requiredSettings.Keys) {
            if (-not $seenKeys.ContainsKey($key)) {
                $lines.Add("$key=$($requiredSettings[$key])")
            }
        }
    }

    foreach ($line in $ExistingLines) {
        if ($line -match '^\s*\[(?<section>[^\]]+)\]\s*$') {
            if ($inWsl2) {
                Add-MissingWsl2Settings
                $seenKeys = @{}
            }
            $inWsl2 = $Matches["section"] -eq "wsl2"
            $sawWsl2 = $sawWsl2 -or $inWsl2
            $lines.Add($line)
            continue
        }

        if ($inWsl2 -and $line -match '^\s*(?<key>[^#;=\s]+)\s*=') {
            $key = $Matches["key"]
            if ($requiredSettings.Contains($key)) {
                $lines.Add("$key=$($requiredSettings[$key])")
                $seenKeys[$key] = $true
                continue
            }
        }

        $lines.Add($line)
    }

    if ($inWsl2) {
        Add-MissingWsl2Settings
    }

    if (-not $sawWsl2) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne "") {
            $lines.Add("")
        }
        $lines.Add("[wsl2]")
        foreach ($key in $requiredSettings.Keys) {
            $lines.Add("$key=$($requiredSettings[$key])")
        }
    }

    return $lines.ToArray()
}

function Backup-WslConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $backupPath = "$Path.open-lola-backup"
    if ($PSCmdlet.ShouldProcess($backupPath, "write backup of existing WSL config")) {
        Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    }
}

function Set-LolaWslConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Path)

    $existingLines = @()
    if (Test-Path -LiteralPath $Path) {
        $existingLines = Get-Content -LiteralPath $Path
    }
    $mergedLines = Merge-WslConfigText -ExistingLines $existingLines

    if ($PSCmdlet.ShouldProcess($Path, "merge LoLa WSL NAT settings")) {
        Backup-WslConfig -Path $Path
        Set-Content -LiteralPath $Path -Value $mergedLines -Encoding ASCII
    }
}

function Add-LolaWindowsFirewallRule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Name,
        [int[]]$Ports,
        [string]$FirewallProfile,
        [string]$Alias
    )

    if ($PSCmdlet.ShouldProcess($Name, "allow inbound UDP ports $($Ports -join ',') on $Alias")) {
        New-NetFirewallRule -DisplayName $Name `
            -Direction Inbound `
            -Action Allow `
            -Protocol UDP `
            -LocalPort $Ports `
            -Profile $FirewallProfile `
            -InterfaceAlias $Alias `
            -ErrorAction Stop | Out-Host
    }
}

function Add-LolaHyperVFirewallRule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Name,
        [string]$VmCreatorId,
        [string]$PortString
    )

    if (-not (Get-Command New-NetFirewallHyperVRule -ErrorAction SilentlyContinue)) {
        Write-Information "New-NetFirewallHyperVRule is unavailable on this Windows build; skipping Hyper-V rule." -InformationAction Continue
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, "allow WSL Hyper-V UDP ports $PortString")) {
        New-NetFirewallHyperVRule -Name $Name `
            -DisplayName $Name `
            -VMCreatorId $VmCreatorId `
            -Direction Inbound `
            -Action Allow `
            -Protocol UDP `
            -LocalPorts $PortString `
            -ErrorAction Stop | Out-Host
    }
}

function Invoke-LolaWslShutdown {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($SkipWslShutdown) {
        Write-Information "Skipping WSL shutdown because -SkipWslShutdown was supplied." -InformationAction Continue
        return
    }

    if ($PSCmdlet.ShouldProcess("WSL", "shutdown to apply networking changes")) {
        wsl --shutdown
    }
}

$lolaUdpPortString = $UdpPorts -join ","

Write-Information "Merging WSL NAT networking config..." -InformationAction Continue
Set-LolaWslConfig -Path $ConfigPath

Write-Information "Adding scoped Windows firewall rule for LoLa/WSL UDP..." -InformationAction Continue
Add-LolaWindowsFirewallRule -Name $RuleName -Ports $UdpPorts -FirewallProfile $FirewallProfile -Alias $InterfaceAlias

Write-Information "Adding scoped Hyper-V firewall rule for WSL if supported..." -InformationAction Continue
Add-LolaHyperVFirewallRule -Name $RuleName -VmCreatorId $WslVmCreatorId -PortString $lolaUdpPortString

Write-Information "Applying WSL networking changes..." -InformationAction Continue
Invoke-LolaWslShutdown
Write-Information "Done. Restart WSL and rerun the probe." -InformationAction Continue
