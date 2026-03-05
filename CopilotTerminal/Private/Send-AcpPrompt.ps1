function Send-AcpPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Prompt,

        [switch]$ApproveTools
    )
    # TODO: Implement - builds a JSON-RPC createSession/turn request with the
    # given prompt messages, sends it over the ACP TCP connection, reads the
    # streaming response events, and renders output to the host
    Write-Warning "Send-AcpPrompt is not yet implemented."
}
