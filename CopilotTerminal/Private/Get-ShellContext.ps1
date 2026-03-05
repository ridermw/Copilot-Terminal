function Get-ShellContext {
    [CmdletBinding()]
    param()

    $config = Get-CopilotConfig

    $parts = @()

    # Always include CWD
    $parts += "cwd=$((Get-Location).Path)"

    # Git info (fast commands — rev-parse and status --porcelain -uno)
    if ($config.context.includeGitInfo) {
        $gitInfo = Get-GitInfoFast
        if ($gitInfo) {
            $parts += "git=$gitInfo"
        }
    }

    # Recent command history
    if ($config.context.includeHistory) {
        $count = $config.context.historyCount
        if (-not $count -or $count -le 0) { $count = 5 }
        $history = Get-History -Count $count -ErrorAction SilentlyContinue |
            ForEach-Object { $_.CommandLine } |
            Where-Object { $_ -and $_ -notmatch '^copilot[:\!]' }
        if ($history) {
            $recentStr = ($history | ForEach-Object {
                if ($_.Length -gt 40) { $_.Substring(0, 37) + '...' } else { $_ }
            }) -join ','
            $parts += "recent=$recentStr"
        }
    }

    # Last error / exit code
    if ($config.context.includeLastOutput) {
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            $parts += "last_exit=$LASTEXITCODE"
        }
        if ($Error.Count -gt 0) {
            $lastErr = $Error[0].ToString()
            if ($lastErr.Length -gt 100) { $lastErr = $lastErr.Substring(0, 97) + '...' }
            $lastErr = $lastErr -replace ';', ','
            $parts += "last_err=$lastErr"
        }
    }

    # OS & shell info
    if ($config.context.includeOsInfo) {
        $osInfo = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } elseif ($IsLinux) { "Linux" } else { $env:OS }
        $psVer = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        $parts += "os=$osInfo;ps=$psVer"
    }

    $contextString = $parts -join ';'
    return "[ctx] $contextString"
}

function Get-GitInfoFast {
    [CmdletBinding()]
    param()

    try {
        $gitDir = git rev-parse --git-dir 2>$null
        if (-not $gitDir) { return $null }

        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $branch) { return $null }

        $statusLines = @(git status --porcelain -uno 2>$null)
        $modCount = ($statusLines | Where-Object { $_ }).Count

        $info = $branch.Trim()
        if ($modCount -gt 0) { $info += "+${modCount}mod" }
        return $info
    } catch {
        return $null
    }
}
