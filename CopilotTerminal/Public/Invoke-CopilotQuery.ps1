function Invoke-CopilotQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Question = '',

        [switch]$NoContext,

        [string]$Model,

        [switch]$ApproveTools,

        [string]$Trigger
    )

    # Echo the trigger line so the user sees what they typed
    if ($Trigger) {
        Write-Host $Trigger -ForegroundColor DarkYellow
    }

    # Handle empty question — show help
    if (-not $Question -or $Question.Trim() -eq '') {
        Show-CopilotHelp
        return
    }

    $config = Get-CopilotConfig

    # Resolve ApproveTools: switch takes precedence, then config default
    $shouldApproveTools = $ApproveTools.IsPresent -or $config.copilot.autoApproveTools

    # Ensure ACP server is running
    if ($config.server.autoStart) {
        Start-CopilotServer
    } else {
        $port = $config.server.port
        if (-not (Test-AcpPort -Port $port)) {
            Write-Error "Copilot server not running on port $port. Run Start-CopilotServer or set autoStart=true in config."
            return
        }
    }

    # Connect if not connected (lazy, once per terminal)
    if (-not $script:AcpConnection -or -not $script:AcpConnection.Connected -or -not $script:SessionId) {
        $connected = Connect-AcpServer
        if (-not $connected) {
            return
        }
    }

    # Build prompt array
    $promptParts = @()

    # Context as separate block (if enabled)
    if (-not $NoContext) {
        $context = Get-ShellContext
        if ($context) {
            $promptParts += $context
        }
    }

    # User question
    $promptParts += $Question

    # Send prompt with streaming
    $result = Send-AcpPrompt -Prompt $promptParts -ApproveTools:$shouldApproveTools

    # If connection was lost and repaired, result may be null — that's handled by Send-AcpPrompt
}

function Show-CopilotHelp {
    [CmdletBinding()]
    param()

    $config = Get-CopilotConfig
    $port = $config.server.port
    $serverRunning = Test-AcpPort -Port $port

    Write-Host ""
    Write-Host "  CopilotTerminal — Inline GitHub Copilot for PowerShell" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    copilot: <question>     Q&A mode (tools denied)"
    Write-Host "    copilot! <question>     Agent mode (tools approved)"
    Write-Host "    copilot: {              Multiline block (close with })"
    Write-Host ""
    Write-Host "  Or directly:" -ForegroundColor Yellow
    Write-Host "    Invoke-CopilotQuery -Question 'your question'"
    Write-Host "    Invoke-CopilotQuery -Question 'fix this' -ApproveTools"
    Write-Host ""
    Write-Host "  Server:" -ForegroundColor Yellow
    $statusColor = if ($serverRunning) { 'Green' } else { 'Red' }
    $statusText = if ($serverRunning) { "running (port $port)" } else { "not running (port $port)" }
    Write-Host "    Status: $statusText" -ForegroundColor $statusColor
    if ($script:SessionId) {
        Write-Host "    Session: $($script:SessionId)" -ForegroundColor DarkGray
    }
    Write-Host ""

    if ($script:LastQueryStats) {
        Write-Host "  Last query:" -ForegroundColor Yellow
        Write-Host ("    TTFT: {0}ms | Total: {1:F1}s" -f $script:LastQueryStats.TimeToFirstTokenMs, ($script:LastQueryStats.TotalMs / 1000))
        Write-Host ""
    }
}
