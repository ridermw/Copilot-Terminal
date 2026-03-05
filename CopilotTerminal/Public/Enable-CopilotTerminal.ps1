function Enable-CopilotTerminal {
    [CmdletBinding()]
    param()

    # Prerequisite checks — never throw, never break $PROFILE
    if (-not (Get-Module PSReadLine)) {
        Write-Warning "CopilotTerminal: PSReadLine module not loaded. The 'copilot:' trigger requires PSReadLine."
        return
    }

    if (-not (Get-Command 'copilot' -ErrorAction SilentlyContinue)) {
        Write-Warning "CopilotTerminal: Copilot CLI not found on PATH. Install from: https://docs.github.com/copilot/how-tos/copilot-cli"
        return
    }

    # Save original Enter handler for restoration
    $script:_originalEnterHandler = (Get-PSReadLineKeyHandler -Bound | Where-Object { $_.Key -eq 'Enter' })

    # Initialize block mode state
    $script:_copilotBlockMode = $false
    $script:_copilotBlockBuffer = ''
    $script:_copilotApproveTools = $false

    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        # --- Multiline block mode ---
        if ($script:_copilotBlockMode) {
            if ($line -match '^\s*\}\s*$') {
                # Block close — submit accumulated prompt
                $script:_copilotBlockMode = $false
                $script:_copilotPendingQuestion = $script:_copilotBlockBuffer.Trim()
                $script:_copilotBlockBuffer = ''
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                if ($script:_copilotApproveTools) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-CopilotQuery -Question $script:_copilotPendingQuestion -ApproveTools')
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-CopilotQuery -Question $script:_copilotPendingQuestion')
                }
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            } else {
                # Accumulate block line, show continuation prompt
                if ($script:_copilotBlockBuffer) {
                    $script:_copilotBlockBuffer += "`n$line"
                } else {
                    $script:_copilotBlockBuffer = $line
                }
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            }
            return
        }

        # --- Block open: copilot: { or copilot! { ---
        if ($line -match '^copilot([\:\!])\s*\{\s*$') {
            $script:_copilotBlockMode = $true
            $script:_copilotBlockBuffer = ''
            $script:_copilotApproveTools = ($Matches[1] -eq '!')
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # --- Agent mode: copilot! <question> ---
        if ($line -match '^copilot!\s*(.+)$') {
            $script:_copilotPendingQuestion = $Matches[1]
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-CopilotQuery -Question $script:_copilotPendingQuestion -ApproveTools')
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # --- Q&A mode: copilot: <question> ---
        if ($line -match '^copilot:\s*(.+)$') {
            $script:_copilotPendingQuestion = $Matches[1]
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-CopilotQuery -Question $script:_copilotPendingQuestion')
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # --- Empty copilot: or copilot! → show help ---
        if ($line -match '^copilot[\:\!]\s*$') {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-CopilotQuery -Question ""')
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # --- Normal command — pass through ---
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    Write-Verbose "CopilotTerminal enabled. Type 'copilot: <question>' to ask, 'copilot! <command>' for agent mode."
}
