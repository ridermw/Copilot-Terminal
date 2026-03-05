function Stop-CopilotServer {
    [CmdletBinding()]
    param()

    $pidFile = Join-Path $HOME '.copilot-terminal' 'server.pid'

    if (-not (Test-Path $pidFile)) {
        Write-Verbose "No Copilot ACP server PID file found. Server may not be running."
        return
    }

    $serverPid = (Get-Content $pidFile -Raw).Trim()
    $process = Get-Process -Id $serverPid -ErrorAction SilentlyContinue

    if ($process) {
        Write-Verbose "Stopping Copilot ACP server (PID: $serverPid)..."
        try {
            $process.Kill()
            $process.WaitForExit(5000)  # Wait up to 5s for clean exit
        } catch {
            Write-Warning "Failed to stop server process: $_"
        }
    } else {
        Write-Verbose "Server process (PID: $serverPid) not found. May have already exited."
    }

    # Clean up PID file
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue

    # Clean up module-scoped connection state
    if ($script:AcpConnection) {
        try { $script:AcpConnection.Close() } catch {}
        $script:AcpConnection = $null
    }
    $script:AcpReader = $null
    $script:AcpWriter = $null
    $script:SessionId = $null

    Write-Verbose "Copilot ACP server stopped."
}
