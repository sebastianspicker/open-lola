[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$environmentScriptPattern = Join-Path $repoRoot "env/*.ps1"
$rules = @(
    "PSAvoidUsingWriteHost",
    "PSShouldProcess",
    "PSUseShouldProcessForStateChangingFunctions",
    "PSAvoidAssignmentToAutomaticVariable"
)

Import-Module PSScriptAnalyzer -RequiredVersion 1.24.0
Import-Module Pester -RequiredVersion 5.7.1

$findings = @(Invoke-ScriptAnalyzer -Path $environmentScriptPattern -IncludeRule $rules)
if ($findings.Count -ne 0) {
    $findings | Format-Table -AutoSize | Out-String | Write-Error
    throw "PSScriptAnalyzer found $($findings.Count) issue(s)."
}

$result = Invoke-Pester -Path (Join-Path $PSScriptRoot ".") -PassThru
if ($result.FailedCount -ne 0) {
    throw "Pester reported $($result.FailedCount) failing test(s)."
}
