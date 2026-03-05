function Disable-CopilotTerminal {
    [CmdletBinding()]
    param()

    # Reset block mode state
    $script:_copilotBlockMode = $false
    $script:_copilotBlockBuffer = ''
    $script:_copilotApproveTools = $false

    # Restore default Enter handler
    try {
        Set-PSReadLineKeyHandler -Key Enter -Function AcceptLine
    } catch {
        Write-Warning "Failed to restore default Enter handler: $_"
    }

    Write-Verbose "CopilotTerminal disabled. PSReadLine Enter key restored to default."
}
