function Invoke-CopilotQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Question = '',

        [switch]$NoContext,

        [string]$Model,

        [switch]$ApproveTools
    )
    # TODO: Implement - ensures ACP server, connects, gathers context, sends prompt
    Write-Warning "Invoke-CopilotQuery is not yet implemented."
}
