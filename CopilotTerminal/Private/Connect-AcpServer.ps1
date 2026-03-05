function Connect-AcpServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Port = 19532
    )
    # TODO: Implement - opens a TCP connection to localhost:$Port, creates
    # StreamReader/StreamWriter, performs JSON-RPC initialize handshake, and
    # stores connection objects in module-scoped variables
    Write-Warning "Connect-AcpServer is not yet implemented."
}
