function Send-AcpMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Message
    )

    if (-not $script:AcpWriter) {
        Write-Error "Not connected to ACP server."
        return
    }

    $json = $Message | ConvertTo-Json -Depth 20 -Compress
    $script:AcpWriter.WriteLine($json)
}

function Read-AcpResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$ExpectedId = -1,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMs = 30000
    )

    if (-not $script:AcpReader) {
        Write-Error "Not connected to ACP server."
        return $null
    }

    $stream = $script:AcpConnection.GetStream()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stopwatch.ElapsedMilliseconds -lt $TimeoutMs) {
        if ($stream.DataAvailable) {
            $line = $script:AcpReader.ReadLine()
            if (-not $line) { continue }

            try {
                $msg = $line | ConvertFrom-Json -AsHashtable
            } catch {
                Write-Verbose "Failed to parse ACP message: $line"
                continue
            }

            # If we're waiting for a specific response ID
            if ($ExpectedId -ge 0 -and $msg.ContainsKey('id') -and $msg.id -eq $ExpectedId) {
                return $msg
            }

            # If it's a notification (no id), return it when no specific id expected
            if (-not $msg.ContainsKey('id') -and $ExpectedId -lt 0) {
                return $msg
            }

            # Notification received while waiting for a specific response — skip it
            if (-not $msg.ContainsKey('id')) {
                Write-Verbose "ACP notification received while waiting: $($msg.method)"
                continue
            }
        }

        Start-Sleep -Milliseconds 50
    }

    Write-Warning "Timeout waiting for ACP response (expected id: $ExpectedId)"
    return $null
}
