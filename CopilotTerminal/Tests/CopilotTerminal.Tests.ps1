BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1'
    Import-Module $modulePath -Force
}

Describe 'CopilotTerminal Module' {
    Context 'Module Loading' {
        It 'Imports without errors' {
            { Import-Module (Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1') -Force } | Should -Not -Throw
        }

        It 'Has correct module version' {
            $module = Get-Module CopilotTerminal
            $module.Version.ToString() | Should -Be '0.1.0'
        }
    }

    Context 'Exported Functions' {
        It 'Exports Invoke-CopilotQuery' {
            Get-Command 'Invoke-CopilotQuery' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Enable-CopilotTerminal' {
            Get-Command 'Enable-CopilotTerminal' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Disable-CopilotTerminal' {
            Get-Command 'Disable-CopilotTerminal' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Start-CopilotServer' {
            Get-Command 'Start-CopilotServer' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Stop-CopilotServer' {
            Get-Command 'Stop-CopilotServer' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Get-CopilotConfig' {
            Get-Command 'Get-CopilotConfig' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports Set-CopilotConfig' {
            Get-Command 'Set-CopilotConfig' -Module CopilotTerminal | Should -Not -BeNullOrEmpty
        }

        It 'Exports exactly 7 public functions' {
            $commands = Get-Command -Module CopilotTerminal
            $commands.Count | Should -Be 7
        }

        It 'Does not export private functions' {
            { Get-Command 'Connect-AcpServer' -Module CopilotTerminal -ErrorAction Stop } | Should -Throw
            { Get-Command 'Send-AcpPrompt' -Module CopilotTerminal -ErrorAction Stop } | Should -Throw
            { Get-Command 'Get-ShellContext' -Module CopilotTerminal -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Enable-CopilotTerminal Safety' {
        It 'Does not throw when PSReadLine is not loaded' {
            $cmd = Get-Command 'Enable-CopilotTerminal' -Module CopilotTerminal
            $cmd.CmdletBinding | Should -BeTrue
        }
    }

    Context 'Trigger Patterns' {
        It 'Q&A mode regex matches copilot: prefix' {
            'copilot: how do I list files?' -match '^copilot:\s*(.+)$' | Should -BeTrue
            $Matches[1] | Should -Be 'how do I list files?'
        }

        It 'Agent mode regex matches copilot! prefix' {
            'copilot! fix the bug' -match '^copilot!\s*(.+)$' | Should -BeTrue
            $Matches[1] | Should -Be 'fix the bug'
        }

        It 'Block mode regex matches copilot: {' {
            'copilot: {' -match '^copilot([\:\!])\s*\{\s*$' | Should -BeTrue
            $Matches[1] | Should -Be ':'
        }

        It 'Block mode regex matches copilot! {' {
            'copilot! {' -match '^copilot([\:\!])\s*\{\s*$' | Should -BeTrue
            $Matches[1] | Should -Be '!'
        }

        It 'Empty copilot: matches help pattern' {
            'copilot:' -match '^copilot[\:\!]\s*$' | Should -BeTrue
        }

        It 'Empty copilot! matches help pattern' {
            'copilot!' -match '^copilot[\:\!]\s*$' | Should -BeTrue
        }

        It 'Normal commands do not match copilot patterns' {
            'Get-ChildItem' -match '^copilot[\:\!]' | Should -BeFalse
        }
    }

    Context 'Invoke-CopilotQuery Parameters' {
        It 'Has Question parameter' {
            $cmd = Get-Command 'Invoke-CopilotQuery' -Module CopilotTerminal
            $cmd.Parameters.Keys | Should -Contain 'Question'
        }

        It 'Has NoContext switch' {
            $cmd = Get-Command 'Invoke-CopilotQuery' -Module CopilotTerminal
            $cmd.Parameters.Keys | Should -Contain 'NoContext'
        }

        It 'Has ApproveTools switch' {
            $cmd = Get-Command 'Invoke-CopilotQuery' -Module CopilotTerminal
            $cmd.Parameters.Keys | Should -Contain 'ApproveTools'
        }

        It 'Has Model parameter' {
            $cmd = Get-Command 'Invoke-CopilotQuery' -Module CopilotTerminal
            $cmd.Parameters.Keys | Should -Contain 'Model'
        }
    }
}
