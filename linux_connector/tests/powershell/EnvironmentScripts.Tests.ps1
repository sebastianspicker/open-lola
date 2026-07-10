Describe "Windows environment scripts" {
    It "parse without errors" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $environmentScripts = @(
            (Join-Path $repoRoot "env/install_wsl_ubuntu.ps1"),
            (Join-Path $repoRoot "env/enable_wsl_lola_network.ps1"),
            (Join-Path $repoRoot "env/windows_probe_from_wsl.ps1")
        )
        foreach ($scriptPath in $environmentScripts) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }
    }

    It "uses Information records for status output" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $environmentScripts = @(
            (Join-Path $repoRoot "env/install_wsl_ubuntu.ps1"),
            (Join-Path $repoRoot "env/enable_wsl_lola_network.ps1"),
            (Join-Path $repoRoot "env/windows_probe_from_wsl.ps1")
        )
        $writeHostCommands = @()
        $informationCommands = @()
        foreach ($scriptPath in $environmentScripts) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $commands = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
            $writeHostCommands += $commands | Where-Object { $_.GetCommandName() -eq "Write-Host" }
            $informationCommands += $commands | Where-Object { $_.GetCommandName() -eq "Write-Information" }
        }

        $writeHostCommands | Should -BeNullOrEmpty
        $informationCommands.Count | Should -Be 18
        foreach ($command in $informationCommands) {
            $command.Extent.Text | Should -Match '(?i)-InformationAction\s+Continue'
        }
    }

    It "declares ShouldProcess on every mutating helper" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $scriptPath = Join-Path $repoRoot "env/enable_wsl_lola_network.ps1"
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        foreach ($name in @(
            "Backup-WslConfig",
            "Set-LolaWslConfig",
            "Add-LolaWindowsFirewallRule",
            "Add-LolaHyperVFirewallRule",
            "Invoke-LolaWslShutdown"
        )) {
            $function = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
            $function.Count | Should -Be 1
            $function[0].Body.ParamBlock.Attributes.TypeName.FullName | Should -Contain "CmdletBinding"
            $function[0].Body.ParamBlock.Attributes.Extent.Text | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        }
    }
}

Describe "enable_wsl_lola_network.ps1 safety" {
    BeforeAll {
        Set-Item -Path function:New-NetFirewallRule -Value {}
        Set-Item -Path function:New-NetFirewallHyperVRule -Value {}
        function wsl {}
    }

    BeforeEach {
        Mock Copy-Item {}
        Mock Set-Content {}
        Mock New-NetFirewallRule {}
        Mock New-NetFirewallHyperVRule {}
        Mock wsl {}
        Mock Get-Command {
            [pscustomobject]@{ Name = "New-NetFirewallHyperVRule" }
        } -ParameterFilter { $Name -eq "New-NetFirewallHyperVRule" }
    }

    It "performs no mutations with WhatIf" {
        $scriptPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\\..")) "env/enable_wsl_lola_network.ps1"
        $configPath = Join-Path $TestDrive ".wslconfig"
        [System.IO.File]::WriteAllText($configPath, "[wsl2]`nfirewall=true")
        $informationRecords = @(& $scriptPath -ConfigPath $configPath -WhatIf -Confirm:$false 6>&1)

        $informationRecords | Should -Not -BeNullOrEmpty
        Should -Invoke Copy-Item -Times 0 -Exactly
        Should -Invoke Set-Content -Times 0 -Exactly
        Should -Invoke New-NetFirewallRule -Times 0 -Exactly
        Should -Invoke New-NetFirewallHyperVRule -Times 0 -Exactly
        Should -Invoke wsl -Times 0 -Exactly
    }

    It "runs the configured config and firewall operations with mocks" {
        $scriptPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\\..")) "env/enable_wsl_lola_network.ps1"
        $configPath = Join-Path $TestDrive ".wslconfig"
        [System.IO.File]::WriteAllText($configPath, "[wsl2]`nfirewall=true")
        $informationRecords = @(& $scriptPath -ConfigPath $configPath -SkipWslShutdown -Confirm:$false 6>&1)

        $informationRecords | Should -Not -BeNullOrEmpty
        Should -Invoke Copy-Item -Times 1 -Exactly
        Should -Invoke Set-Content -Times 1 -Exactly
        Should -Invoke New-NetFirewallRule -Times 1 -Exactly
        Should -Invoke New-NetFirewallHyperVRule -Times 1 -Exactly
        Should -Invoke wsl -Times 0 -Exactly
    }
}
