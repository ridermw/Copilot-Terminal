function Set-CopilotConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [string]$Model,

        [Parameter(Mandatory = $false)]
        [bool]$AutoStart,

        [Parameter(Mandatory = $false)]
        [bool]$AutoApproveTools,

        [Parameter(Mandatory = $false)]
        [int]$HistoryCount,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeHistory,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeLastOutput,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeGitInfo,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeOsInfo,

        [Parameter(Mandatory = $false)]
        [string[]]$ExtraArgs
    )

    $homeDir = if ($env:HOME) { $env:HOME } else { $HOME }
    $configDir = Join-Path $homeDir '.copilot-terminal'
    $configFile = Join-Path $configDir 'config.json'

    # Load existing or start fresh
    if (Test-Path $configFile) {
        try {
            $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            Write-Warning "Existing config malformed. Starting fresh."
            $config = @{}
        }
    } else {
        $config = @{}
    }

    # Ensure nested hashtables exist
    if (-not $config.ContainsKey('server')) { $config['server'] = @{} }
    if (-not $config.ContainsKey('context')) { $config['context'] = @{} }
    if (-not $config.ContainsKey('copilot')) { $config['copilot'] = @{} }

    # Apply values if provided (use $PSBoundParameters to detect what was actually passed)
    if ($PSBoundParameters.ContainsKey('Port')) { $config['server']['port'] = $Port }
    if ($PSBoundParameters.ContainsKey('AutoStart')) { $config['server']['autoStart'] = $AutoStart }
    if ($PSBoundParameters.ContainsKey('Model')) { $config['copilot']['model'] = $Model }
    if ($PSBoundParameters.ContainsKey('AutoApproveTools')) { $config['copilot']['autoApproveTools'] = $AutoApproveTools }
    if ($PSBoundParameters.ContainsKey('ExtraArgs')) { $config['copilot']['extraArgs'] = $ExtraArgs }
    if ($PSBoundParameters.ContainsKey('HistoryCount')) { $config['context']['historyCount'] = $HistoryCount }
    if ($PSBoundParameters.ContainsKey('IncludeHistory')) { $config['context']['includeHistory'] = $IncludeHistory }
    if ($PSBoundParameters.ContainsKey('IncludeLastOutput')) { $config['context']['includeLastOutput'] = $IncludeLastOutput }
    if ($PSBoundParameters.ContainsKey('IncludeGitInfo')) { $config['context']['includeGitInfo'] = $IncludeGitInfo }
    if ($PSBoundParameters.ContainsKey('IncludeOsInfo')) { $config['context']['includeOsInfo'] = $IncludeOsInfo }

    # Create directory if needed
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Write config
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding utf8
    Write-Verbose "Config saved to $configFile"
}
