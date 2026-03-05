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
                $question = $script:_copilotBlockBuffer.Trim()
                $script:_copilotBlockBuffer = ''
                $approveTools = $script:_copilotApproveTools
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
                if ($approveTools) {
                    Write-Host "copilot! {multiline}"
                    Invoke-CopilotQuery -Question $question -ApproveTools
                } else {
                    Write-Host "copilot: {multiline}"
                    Invoke-CopilotQuery -Question $question
                }
            } else {
                # Accumulate block line
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
            $question = $Matches[1]
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            Write-Host "copilot! $question"
            Invoke-CopilotQuery -Question $question -ApproveTools
            return
        }

        # --- Q&A mode: copilot: <question> ---
        if ($line -match '^copilot:\s*(.+)$') {
            $question = $Matches[1]
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            Write-Host "copilot: $question"
            Invoke-CopilotQuery -Question $question
            return
        }

        # --- Empty copilot: or copilot! → help ---
        if ($line -match '^copilot[\:\!]\s*$') {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            Invoke-CopilotQuery -Question ''
            return
        }

        # --- Normal command — pass through ---
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    Write-Host ""
    Write-Host "  ✅ CopilotTerminal enabled" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Triggers:" -ForegroundColor DarkGray
    Write-Host "    copilot: <question>   Q&A mode" -ForegroundColor DarkGray
    Write-Host "    copilot! <command>    Agent mode" -ForegroundColor DarkGray
    Write-Host "    copilot: {            Multiline block" -ForegroundColor DarkGray
    Write-Host ""
}
