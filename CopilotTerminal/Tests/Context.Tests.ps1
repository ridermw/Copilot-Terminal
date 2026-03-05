$modulePath = Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1'
Import-Module $modulePath -Force

Describe 'Get-ShellContext' {
    It 'Returns string starting with [ctx]' {
        $result = InModuleScope CopilotTerminal { Get-ShellContext }
        $result | Should Match '^\[ctx\] '
    }

    It 'Always includes cwd' {
        $result = InModuleScope CopilotTerminal { Get-ShellContext }
        $result | Should Match 'cwd='
    }

    It 'Includes OS info' {
        $result = InModuleScope CopilotTerminal { Get-ShellContext }
        $result | Should Match 'os='
        $result | Should Match 'ps='
    }

    It 'Returns compact key=value format with semicolons' {
        $result = InModuleScope CopilotTerminal { Get-ShellContext }
        ($result -split ';').Count | Should BeGreaterThan 1
    }

    Context 'In a git repository' {
        It 'Includes git info when in a repo' {
            $toplevel = git rev-parse --show-toplevel 2>$null
            Push-Location $toplevel
            try {
                $result = InModuleScope CopilotTerminal { Get-ShellContext }
                $result | Should Match 'git='
            } finally {
                Pop-Location
            }
        }
    }

    Context 'Not in a git repository' {
        It 'Skips git info gracefully when not in repo' {
            Push-Location $TestDrive
            try {
                $result = InModuleScope CopilotTerminal { Get-ShellContext }
                $result | Should Not Match 'git='
                $result | Should Match 'cwd='
            } finally {
                Pop-Location
            }
        }
    }

    Context 'Context configuration' {
        It 'Respects includeGitInfo=false' {
            $origHome = $env:HOME
            $env:HOME = Join-Path $TestDrive 'home-ctx'
            New-Item -ItemType Directory -Path $env:HOME -Force | Out-Null
            $configDir = Join-Path $env:HOME '.copilot-terminal'
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            @{ context = @{ includeGitInfo = $false; includeHistory = $true; includeLastOutput = $true; includeOsInfo = $true; historyCount = 5 } } |
                ConvertTo-Json -Depth 5 | Set-Content (Join-Path $configDir 'config.json')

            try {
                Import-Module (Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1') -Force
                $result = InModuleScope CopilotTerminal { Get-ShellContext }
                $result | Should Not Match 'git='
            } finally {
                $env:HOME = $origHome
                Import-Module (Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1') -Force
            }
        }
    }
}
