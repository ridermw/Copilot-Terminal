# CopilotTerminal.psm1 — Module loader
# Inline GitHub Copilot integration for PowerShell via PSReadLine hook and ACP protocol

#region Module-scoped state
$script:AcpConnection       = $null   # System.Net.Sockets.TcpClient
$script:AcpReader           = $null   # System.IO.StreamReader
$script:AcpWriter           = $null   # System.IO.StreamWriter
$script:SessionId            = $null
$script:RequestId            = 0
$script:_copilotPendingQuestion = ''
$script:_copilotBlockMode    = $false
$script:_copilotBlockBuffer  = ''
$script:_copilotApproveTools = $false
$script:LastQueryStats       = $null
#endregion

#region Dot-source private helpers then public commands
$privatePath = Join-Path $PSScriptRoot 'Private'
$publicPath  = Join-Path $PSScriptRoot 'Public'

foreach ($scope in @($privatePath, $publicPath)) {
    if (Test-Path $scope) {
        foreach ($file in Get-ChildItem -Path $scope -Filter '*.ps1' -File) {
            try {
                . $file.FullName
            }
            catch {
                Write-Warning "CopilotTerminal: failed to load $($file.Name): $_"
            }
        }
    }
}
#endregion

#region Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($script:AcpConnection) {
        try { $script:AcpConnection.Dispose() } catch { }
        $script:AcpConnection = $null
        $script:AcpReader     = $null
        $script:AcpWriter     = $null
    }
}
#endregion
