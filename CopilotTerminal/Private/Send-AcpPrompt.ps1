function Send-AcpPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Prompt,

        [switch]$ApproveTools
    )

    if (-not $script:AcpConnection -or -not $script:AcpConnection.Connected) {
        Write-Error "Not connected to ACP server. Run Connect-AcpServer first."
        return $null
    }

    if (-not $script:SessionId) {
        Write-Error "No active ACP session."
        return $null
    }

    # Build prompt content array
    $promptContent = @()
    foreach ($p in $Prompt) {
        $promptContent += @{ type = 'text'; text = $p }
    }

    # Send session/prompt
    $script:RequestId++
    $promptId = $script:RequestId
    $promptRequest = @{
        jsonrpc = '2.0'
        id      = $promptId
        method  = 'session/prompt'
        params  = @{
            sessionId = $script:SessionId
            prompt    = $promptContent
        }
    }

    try {
        Send-AcpMessage -Message $promptRequest
    } catch {
        Write-Warning "`u{26A0} Connection to Copilot lost while sending. Attempting reconnect..."
        if (Repair-AcpConnection) {
            $promptRequest.params.sessionId = $script:SessionId
            $script:RequestId++
            $promptRequest.id = $script:RequestId
            $promptId = $script:RequestId
            Send-AcpMessage -Message $promptRequest
        } else {
            Write-Error "Failed to reconnect to Copilot server."
            return $null
        }
    }

    # Read streaming responses
    $stream = $script:AcpConnection.GetStream()
    $responseText = [System.Text.StringBuilder]::new()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $firstTokenTime = $null
    $timeout = 300000  # 5 minute overall timeout

    while ($stopwatch.ElapsedMilliseconds -lt $timeout) {
        try {
            if ($stream.DataAvailable) {
                $line = $script:AcpReader.ReadLine()
                if (-not $line) { continue }

                $msg = $null
                try {
                    $msg = $line | ConvertFrom-Json -AsHashtable
                } catch {
                    continue
                }

                # Response to our prompt request (final result)
                if ($msg.ContainsKey('id') -and $msg.id -eq $promptId) {
                    $script:LastQueryStats = @{
                        TotalMs            = $stopwatch.ElapsedMilliseconds
                        TimeToFirstTokenMs = $firstTokenTime
                        ResponseLength     = $responseText.Length
                    }
                    Write-Host ""  # Final newline after streaming
                    Write-Verbose ("`u{23F1} TTFT: {0}ms | Total: {1:F1}s | Chars: {2}" -f
                        $firstTokenTime,
                        ($stopwatch.ElapsedMilliseconds / 1000),
                        $responseText.Length)

                    if ($msg.result -and $msg.result.stopReason -and $msg.result.stopReason -ne 'end_turn') {
                        Write-Verbose "Prompt finished with stopReason=$($msg.result.stopReason)"
                    }
                    return $msg.result
                }

                # Notification: session/update
                if ($msg.method -eq 'session/update' -and $msg.params) {
                    $update = $msg.params.update
                    if (-not $update) { $update = $msg.params }

                    if ($update.sessionUpdate -eq 'agent_message_chunk' -and $update.content -and $update.content.type -eq 'text') {
                        if (-not $firstTokenTime) {
                            $firstTokenTime = $stopwatch.ElapsedMilliseconds
                        }
                        $chunk = $update.content.text
                        [void]$responseText.Append($chunk)
                        Write-Host $chunk -NoNewline
                    }
                }

                # Notification: session/request_permission
                if ($msg.method -eq 'session/request_permission') {
                    $permissionId = $msg.id
                    if ($ApproveTools) {
                        $permResponse = @{
                            jsonrpc = '2.0'
                            id      = $permissionId
                            result  = @{ outcome = @{ outcome = 'approved' } }
                        }
                    } else {
                        $permResponse = @{
                            jsonrpc = '2.0'
                            id      = $permissionId
                            result  = @{ outcome = @{ outcome = 'cancelled' } }
                        }
                    }
                    Send-AcpMessage -Message $permResponse
                }
            } else {
                Start-Sleep -Milliseconds 20
            }
        } catch {
            # Connection lost mid-stream
            if ($responseText.Length -gt 0) {
                Write-Host ""
                Write-Warning "`u{26A0} Connection to Copilot lost - partial response above."
            } else {
                Write-Warning "`u{26A0} Connection to Copilot lost."
            }

            $oldSessionId = $script:SessionId
            $script:SessionId = $null
            $script:AcpConnection = $null
            $script:_lastSessionId = $oldSessionId
            return $null
        }
    }

    Write-Warning "Prompt timed out after 5 minutes."
    return $null
}
