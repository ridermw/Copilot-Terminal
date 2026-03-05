function Merge-Hashtable {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )
    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtable -Base $result[$key] -Override $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}

function Get-CopilotConfig {
    [CmdletBinding()]
    param(
        [switch]$Raw
    )
    # Config path — prefer $env:HOME for testability, fall back to $HOME
    $homeDir = if ($env:HOME) { $env:HOME } else { $HOME }
    $configDir = Join-Path $homeDir '.copilot-terminal'
    $configFile = Join-Path $configDir 'config.json'

    # Load defaults from module's Config/ directory
    $defaultsPath = Join-Path $PSScriptRoot '..' 'Config' 'default-config.json'
    $defaults = Get-Content -Path $defaultsPath -Raw | ConvertFrom-Json -AsHashtable

    # If no user config, return defaults (or empty for -Raw)
    if (-not (Test-Path $configFile)) {
        if ($Raw) { return @{} }
        return $defaults
    }

    # Load user config
    try {
        $userConfig = Get-Content -Path $configFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warning "Malformed config at ${configFile}: $_. Using defaults."
        if ($Raw) { return @{} }
        return $defaults
    }

    if ($Raw) { return $userConfig }

    # Deep merge: user values override defaults
    $merged = Merge-Hashtable -Base $defaults -Override $userConfig
    return $merged
}
