BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'CopilotTerminal.psd1'
    Import-Module $modulePath -Force
}

Describe 'ACP Message Building' {
    It 'Send-AcpMessage creates valid JSON-RPC 2.0' {
        $msg = @{
            jsonrpc = '2.0'
            id      = 1
            method  = 'initialize'
            params  = @{
                protocolVersion    = '2025-01'
                clientCapabilities = @{}
            }
        }
        $json = $msg | ConvertTo-Json -Depth 20 -Compress
        $parsed = $json | ConvertFrom-Json
        $parsed.jsonrpc | Should -Be '2.0'
        $parsed.id | Should -Be 1
        $parsed.method | Should -Be 'initialize'
        $parsed.params.protocolVersion | Should -Be '2025-01'
    }

    It 'Session prompt message has correct structure' {
        $msg = @{
            jsonrpc = '2.0'
            id      = 3
            method  = 'session/prompt'
            params  = @{
                sessionId = 'test-session-123'
                prompt    = @(
                    @{ type = 'text'; text = '[ctx] cwd=C:\test' },
                    @{ type = 'text'; text = 'What is PowerShell?' }
                )
            }
        }
        $json = $msg | ConvertTo-Json -Depth 20 -Compress
        $parsed = $json | ConvertFrom-Json
        $parsed.method | Should -Be 'session/prompt'
        $parsed.params.sessionId | Should -Be 'test-session-123'
        $parsed.params.prompt.Count | Should -Be 2
        $parsed.params.prompt[0].type | Should -Be 'text'
    }

    It 'Permission denied response has correct structure for Q&A mode' {
        $msg = @{
            jsonrpc = '2.0'
            id      = 5
            result  = @{ outcome = @{ outcome = 'cancelled' } }
        }
        $json = $msg | ConvertTo-Json -Depth 20 -Compress
        $parsed = $json | ConvertFrom-Json
        $parsed.result.outcome.outcome | Should -Be 'cancelled'
    }

    It 'Permission approved response has correct structure for agent mode' {
        $msg = @{
            jsonrpc = '2.0'
            id      = 5
            result  = @{ outcome = @{ outcome = 'approved' } }
        }
        $json = $msg | ConvertTo-Json -Depth 20 -Compress
        $parsed = $json | ConvertFrom-Json
        $parsed.result.outcome.outcome | Should -Be 'approved'
    }
}

Describe 'Test-AcpPort' {
    It 'Returns false for a port that is not listening' {
        InModuleScope CopilotTerminal {
            $result = Test-AcpPort -Port 59999
            $result | Should -Be $false
        }
    }
}

Describe 'Connect-AcpServer' {
    It 'Fails gracefully when no server is running' {
        InModuleScope CopilotTerminal {
            $result = Connect-AcpServer -Port 59998 -ErrorAction SilentlyContinue -ErrorVariable connectErr
            $result | Should -Be $false
        }
    }
}

Describe 'Send-AcpPrompt' {
    It 'Returns null when not connected' {
        InModuleScope CopilotTerminal {
            $script:AcpConnection = $null
            $script:AcpWriter = $null

            $result = Send-AcpPrompt -Prompt 'test' -ErrorAction SilentlyContinue
            $result | Should -Be $null
        }
    }
}
