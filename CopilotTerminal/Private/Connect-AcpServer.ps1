function Connect-AcpServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Port = 0
    )

    if ($Port -eq 0) {
        $config = Get-CopilotConfig
        $Port = $config.server.port
    }

    # Close existing connection if any
    if ($script:AcpConnection -and $script:AcpConnection.Connected) {
        try { $script:AcpConnection.Close() } catch {}
    }

    # TCP connect
    Write-Verbose "Connecting to Copilot ACP server on port $Port..."
    try {
        $script:AcpConnection = [System.Net.Sockets.TcpClient]::new()
        $script:AcpConnection.Connect('127.0.0.1', $Port)
        $stream = $script:AcpConnection.GetStream()
        $script:AcpReader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        $script:AcpWriter = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)
        $script:AcpWriter.AutoFlush = $true
        $script:RequestId = 0
    } catch {
        Write-Error "Failed to connect to Copilot ACP server on port ${Port}: $_"
        return $false
    }

    # Send initialize
    $script:RequestId++
    $initRequest = @{
        jsonrpc = '2.0'
        id      = $script:RequestId
        method  = 'initialize'
        params  = @{
            protocolVersion    = '2025-01'
            clientCapabilities = @{}
        }
    }
    Send-AcpMessage -Message $initRequest

    # Read initialize response
    $initResponse = Read-AcpResponse -ExpectedId $script:RequestId
    if (-not $initResponse) {
        Write-Error "No response from ACP server during initialize."
        return $false
    }

    # Protocol version check (warn, don't fail)
    if ($initResponse.result -and $initResponse.result.protocolVersion) {
        $serverVersion = $initResponse.result.protocolVersion
        if ($serverVersion -ne '2025-01') {
            Write-Warning "ACP protocol version mismatch (server: $serverVersion, expected: 2025-01). Some features may not work. Update CopilotTerminal module."
        }
    }

    # Send session/new
    $script:RequestId++
    $sessionRequest = @{
        jsonrpc = '2.0'
        id      = $script:RequestId
        method  = 'session/new'
        params  = @{
            cwd        = (Get-Location).Path
            mcpServers = @()
        }
    }
    Send-AcpMessage -Message $sessionRequest

    # Read session/new response
    $sessionResponse = Read-AcpResponse -ExpectedId $script:RequestId
    if (-not $sessionResponse -or -not $sessionResponse.result) {
        Write-Error "Failed to create ACP session."
        return $false
    }

    $script:SessionId = $sessionResponse.result.sessionId
    Write-Verbose "ACP session created: $($script:SessionId)"
    return $true
}

function Repair-AcpConnection {
    [CmdletBinding()]
    param()

    $config = Get-CopilotConfig
    $port = $config.server.port
    $oldSessionId = $script:SessionId

    Write-Verbose "Attempting to reconnect to ACP server..."

    try {
        $script:AcpConnection = [System.Net.Sockets.TcpClient]::new()
        $script:AcpConnection.Connect('127.0.0.1', $port)
        $stream = $script:AcpConnection.GetStream()
        $script:AcpReader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        $script:AcpWriter = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)
        $script:AcpWriter.AutoFlush = $true
    } catch {
        Write-Warning "Reconnect failed: $_"
        return $false
    }

    # Re-initialize
    $script:RequestId++
    Send-AcpMessage -Message @{
        jsonrpc = '2.0'; id = $script:RequestId; method = 'initialize'
        params  = @{ protocolVersion = '2025-01'; clientCapabilities = @{} }
    }
    $initResp = Read-AcpResponse -ExpectedId $script:RequestId
    if (-not $initResp) { return $false }

    # Try to resume old session
    if ($oldSessionId) {
        $script:RequestId++
        Send-AcpMessage -Message @{
            jsonrpc = '2.0'; id = $script:RequestId; method = 'session/load'
            params  = @{ sessionId = $oldSessionId }
        }
        $loadResp = Read-AcpResponse -ExpectedId $script:RequestId -TimeoutMs 5000
        if ($loadResp -and $loadResp.result) {
            $script:SessionId = $oldSessionId
            Write-Verbose "Resumed previous session: $oldSessionId"
            return $true
        }
    }

    # Create new session
    Write-Warning "Previous session unavailable. Starting fresh."
    $script:RequestId++
    Send-AcpMessage -Message @{
        jsonrpc = '2.0'; id = $script:RequestId; method = 'session/new'
        params  = @{ cwd = (Get-Location).Path; mcpServers = @() }
    }
    $newResp = Read-AcpResponse -ExpectedId $script:RequestId
    if ($newResp -and $newResp.result) {
        $script:SessionId = $newResp.result.sessionId
        return $true
    }

    return $false
}
