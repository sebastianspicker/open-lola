# Validate canonical Windows scripts and their legacy compatibility wrappers.
Describe "Windows environment scripts" {
    It "parses canonical scripts and compatibility wrappers without errors" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $environmentScripts = @(
            (Join-Path $repoRoot "env/install_wsl_ubuntu.ps1"),
            (Join-Path $repoRoot "env/enable_wsl_lola_network.ps1"),
            (Join-Path $repoRoot "env/windows_probe_from_wsl.ps1"),
            (Join-Path $repoRoot "deployment/wsl/install_wsl_ubuntu.ps1"),
            (Join-Path $repoRoot "deployment/wsl/enable_wsl_lola_network.ps1"),
            (Join-Path $repoRoot "deployment/wsl/windows_probe_from_wsl.ps1")
        )
        foreach ($scriptPath in $environmentScripts) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }
    }

    It "forwards each legacy PowerShell parameter contract to the canonical script" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $scriptPairs = @(
            @{ Name = "install_wsl_ubuntu.ps1" },
            @{ Name = "enable_wsl_lola_network.ps1" },
            @{ Name = "windows_probe_from_wsl.ps1" }
        )
        foreach ($pair in $scriptPairs) {
            $legacyPath = Join-Path $repoRoot "env/$($pair.Name)"
            $canonicalPath = Join-Path $repoRoot "deployment/wsl/$($pair.Name)"
            $legacyAst = [System.Management.Automation.Language.Parser]::ParseFile($legacyPath, [ref]$null, [ref]$null)
            $canonicalAst = [System.Management.Automation.Language.Parser]::ParseFile($canonicalPath, [ref]$null, [ref]$null)
            $legacyParameters = $legacyAst.ParamBlock.Parameters.Name.VariablePath.UserPath -join ","
            $canonicalParameters = $canonicalAst.ParamBlock.Parameters.Name.VariablePath.UserPath -join ","

            $legacyParameters | Should -Be $canonicalParameters
            $legacyAst.Extent.Text | Should -Match ([regex]::Escape("..\deployment\wsl\$($pair.Name)"))
            $legacyAst.Extent.Text | Should -Match '& \$canonicalScript @PSBoundParameters'
        }
    }

    It "preserves ShouldProcess support on the network compatibility wrapper" {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
        $scriptPath = Join-Path $repoRoot "env/enable_wsl_lola_network.ps1"
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $ast.ParamBlock.Attributes.TypeName.FullName | Should -Contain "CmdletBinding"
        $ast.ParamBlock.Attributes.Extent.Text | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
    }
}

Describe "enable_wsl_lola_network.ps1 safety" {
    BeforeAll {
        Set-Item -Path function:New-NetFirewallRule -Value {}
        Set-Item -Path function:New-NetFirewallHyperVRule -Value {}
        # Define the mocked WSL command used by safety tests before each script invocation.
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
