# Compatibility entry point for the canonical Windows-to-WSL probe launcher.
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

$canonicalScript = Join-Path $PSScriptRoot "..\deployment\wsl\windows_probe_from_wsl.ps1"
& $canonicalScript @PSBoundParameters
