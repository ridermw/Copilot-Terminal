function Start-CopilotSpinner {
    [CmdletBinding()]
    param()

    $shared = [hashtable]::Synchronized(@{ Running = $true })

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    [void]$ps.AddScript({
        param($state)
        $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
        $i = 0

        # Hide cursor
        [Console]::Write("`e[?25l")

        while ($state.Running) {
            $frame = $frames[$i % $frames.Count]
            [Console]::Write("`r  `e[35m$frame `e[1;35mThinking`e[0m `e[90m(esc to cancel)`e[0m  ")
            $i++
            Start-Sleep -Milliseconds 80
        }

        # Clear the spinner line and restore cursor
        [Console]::Write("`r$(' ' * 40)`r")
        [Console]::Write("`e[?25h")
    }).AddArgument($shared)

    $handle = $ps.BeginInvoke()

    return [PSCustomObject]@{
        PowerShell = $ps
        Handle     = $handle
        Runspace   = $runspace
        Shared     = $shared
    }
}

function Stop-CopilotSpinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Spinner
    )

    if (-not $Spinner) { return }

    $Spinner.Shared.Running = $false

    try {
        if ($Spinner.Handle -and -not $Spinner.Handle.IsCompleted) {
            $Spinner.Handle.AsyncWaitHandle.WaitOne(1000) | Out-Null
        }
        $Spinner.PowerShell.EndInvoke($Spinner.Handle)
    } catch {}

    try { $Spinner.PowerShell.Dispose() } catch {}
    try { $Spinner.Runspace.Close() } catch {}
    try { $Spinner.Runspace.Dispose() } catch {}
}
