$modulePath = Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1'
Import-Module $modulePath -Force

Describe 'Get-CopilotConfig' {
    BeforeEach {
        $script:origHome = $env:HOME
        $env:HOME = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Path $env:HOME -Force | Out-Null
    }
    AfterEach {
        $env:HOME = $script:origHome
    }

    It 'Returns defaults when no user config exists' {
        $config = Get-CopilotConfig
        $config.server.port | Should Be 19532
        $config.server.autoStart | Should Be $true
        $config.copilot.autoApproveTools | Should Be $false
        $config.context.historyCount | Should Be 5
    }

    It 'Returns empty hashtable with -Raw when no user config exists' {
        $raw = Get-CopilotConfig -Raw
        $raw.Keys.Count | Should Be 0
    }

    It 'Merges user config over defaults' {
        $configDir = Join-Path $env:HOME '.copilot-terminal'
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        @{ server = @{ port = 8080 } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $configDir 'config.json')

        $config = Get-CopilotConfig
        $config.server.port | Should Be 8080
        $config.server.autoStart | Should Be $true
        $config.copilot.autoApproveTools | Should Be $false
    }

    It 'Handles malformed JSON gracefully' {
        $configDir = Join-Path $env:HOME '.copilot-terminal'
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        'not json{{{' | Set-Content (Join-Path $configDir 'config.json')

        $config = Get-CopilotConfig -WarningAction SilentlyContinue
        $config.server.port | Should Be 19532
    }
}

Describe 'Set-CopilotConfig' {
    BeforeEach {
        $script:origHome = $env:HOME
        $env:HOME = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Path $env:HOME -Force | Out-Null
    }
    AfterEach {
        $env:HOME = $script:origHome
    }

    It 'Creates config file when none exists' {
        Set-CopilotConfig -Port 9999
        $configFile = Join-Path $env:HOME '.copilot-terminal' 'config.json'
        Test-Path $configFile | Should Be $true
    }

    It 'Round-trips port value' {
        Set-CopilotConfig -Port 9999
        $config = Get-CopilotConfig
        $config.server.port | Should Be 9999
    }

    It 'Preserves existing values when setting a different key' {
        Set-CopilotConfig -Port 9999
        Set-CopilotConfig -Model 'gpt-5.2'
        $config = Get-CopilotConfig -Raw
        $config.server.port | Should Be 9999
        $config.copilot.model | Should Be 'gpt-5.2'
    }

    It 'Sets AutoApproveTools correctly' {
        Set-CopilotConfig -AutoApproveTools $true
        $config = Get-CopilotConfig
        $config.copilot.autoApproveTools | Should Be $true
    }
}
