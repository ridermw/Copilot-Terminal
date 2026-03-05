function Start-CopilotServer {
    [CmdletBinding()]
    param()

    $config = Get-CopilotConfig
    $port = $config.server.port

    # Check if copilot CLI is available
    $copilotCmd = Get-Command 'copilot' -ErrorAction SilentlyContinue
    if (-not $copilotCmd) {
        Write-Error "Copilot CLI not found. Install from: https://docs.github.com/copilot/how-tos/copilot-cli"
        return
    }

    # Check if port is already listening (server already running)
    if (Test-AcpPort -Port $port) {
        Write-Verbose "Copilot ACP server already listening on port $port"
        return
    }

    # Check for stale PID file
    $pidFile = Join-Path $HOME '.copilot-terminal' 'server.pid'
    if (Test-Path $pidFile) {
        $oldPid = Get-Content $pidFile -Raw
        $oldPid = $oldPid.Trim()
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if (-not $proc) {
            # Stale PID file — remove it
            Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        }
    }

    # Start copilot ACP server as background process
    # No --allow-all on server; permission decisions are made client-side per-query
    Write-Verbose "Starting Copilot ACP server on port $port..."

    $processArgs = @('--acp', '--port', $port.ToString())

    # Add any extra args from config
    if ($config.copilot.extraArgs -and $config.copilot.extraArgs.Count -gt 0) {
        $processArgs += $config.copilot.extraArgs
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command 'copilot').Source
    $startInfo.Arguments = $processArgs -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    try {
        $process = [System.Diagnostics.Process]::Start($startInfo)
    } catch {
        Write-Error "Failed to start Copilot ACP server: $_"
        return
    }

    # Store PID
    $pidDir = Join-Path $HOME '.copilot-terminal'
    if (-not (Test-Path $pidDir)) {
        New-Item -ItemType Directory -Path $pidDir -Force | Out-Null
    }
    $process.Id.ToString() | Set-Content -Path $pidFile -NoNewline

    # Poll for port availability (up to 10 seconds)
    $timeout = 10
    $interval = 0.5
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Milliseconds ([int]($interval * 1000))
        $elapsed += $interval

        # Check if process died
        if ($process.HasExited) {
            $stderr = $process.StandardError.ReadToEnd()
            Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
            if ($stderr -match 'auth' -or $stderr -match 'login' -or $stderr -match 'token') {
                Write-Error "Copilot not authenticated. Run 'copilot login' first."
            } else {
                Write-Error "Copilot ACP server exited unexpectedly: $stderr"
            }
            return
        }

        if (Test-AcpPort -Port $port) {
            Write-Verbose "Copilot ACP server ready on port $port (PID: $($process.Id))"
            return
        }
    }

    # Timeout
    Write-Warning "Copilot ACP server started (PID: $($process.Id)) but port $port not yet responding after ${timeout}s. It may still be initializing."
}
