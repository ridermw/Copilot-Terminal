BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1'
}

Describe 'CopilotTerminal Module' {
    It 'Should import without errors' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should export all expected public functions' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # $expectedFunctions = @(
        #     'Invoke-CopilotQuery', 'Enable-CopilotTerminal', 'Disable-CopilotTerminal',
        #     'Start-CopilotServer', 'Stop-CopilotServer', 'Set-CopilotConfig', 'Get-CopilotConfig'
        # )
        # $mod = Import-Module $modulePath -Force -PassThru
        # $mod.ExportedFunctions.Keys | Should -BeExactly $expectedFunctions
    }

    It 'Should initialise module-scoped state variables' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Verify AcpConnection, SessionId, RequestId, etc. are $null / 0
    }

    It 'Should degrade gracefully when PSReadLine is unavailable' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Enable-CopilotTerminal should warn but not throw when PSReadLine is missing
    }
}
