param(
    [Parameter(Mandatory=$true)]
    [string]$WindowsIp,

    [string]$Distro = "",
    [string]$LocalIp = "",
    [int]$Duration = 20,
    [int]$Width = 640,
    [int]$Height = 480,
    [int]$Fps = 25,
    [int]$Bpp = 8,
    [int]$Channels = 2,
    [int]$SampleRate = 44100,
    [ValidateSet("silence", "sine", "tones", "diagnostic")]
    [string]$TestMedia = "diagnostic",
    [string]$Capture = ""
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$wslArgs = @()
if ($Distro -ne "") {
    $wslArgs += @("-d", $Distro)
}

$wslRepo = (& wsl @wslArgs wslpath -a "$repo").Trim()
if ($LASTEXITCODE -ne 0 -or $wslRepo -eq "") {
    throw "Could not translate repository path into WSL. Is WSL installed and initialized?"
}

$probeArgs = @(
    "--windows-ip", $WindowsIp,
    "--duration", "$Duration",
    "--width", "$Width",
    "--height", "$Height",
    "--fps", "$Fps",
    "--bpp", "$Bpp",
    "--channels", "$Channels",
    "--sr", "$SampleRate",
    "--test-media", $TestMedia
)

if ($LocalIp -ne "") {
    $probeArgs += @("--local-ip", $LocalIp)
}
if ($Capture -ne "") {
    $probeArgs += @("--capture", $Capture)
}

$quotedProbeArgs = ($probeArgs | ForEach-Object { "'" + ($_ -replace "'", "'\''") + "'" }) -join " "
$cmd = "cd '$wslRepo' && chmod +x linux_connector/env/*.sh && ./linux_connector/env/probe_windows_lola.sh $quotedProbeArgs"

Write-Host "Running WSL Linux-LoLa probe from $wslRepo"
& wsl @wslArgs bash -lc $cmd
exit $LASTEXITCODE
