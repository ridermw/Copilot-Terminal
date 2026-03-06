function Start-CopilotSpinner {
    [CmdletBinding()]
    param()

    # Simple static message - works reliably from any context including PSReadLine handlers
    Write-Host "  * " -NoNewline -ForegroundColor Magenta
    Write-Host "Thinking..." -NoNewline -ForegroundColor Magenta

    # Return a marker so Stop knows to clear
    return [PSCustomObject]@{ Active = $true }
}

function Stop-CopilotSpinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Spinner
    )

    if ($Spinner -and $Spinner.Active) {
        # Clear the "Thinking..." line: carriage return + spaces + carriage return
        [Console]::Write("`r$(' ' * 30)`r")
    }
}
