# CopilotTerminal

Inline GitHub Copilot integration for PowerShell. Type `copilot: <question>` in your terminal and get AI-powered answers without leaving your workflow.

## How It Works

CopilotTerminal hooks into PSReadLine to intercept lines starting with `copilot:` or `copilot!`, routing them to a persistent GitHub Copilot CLI agent via the [Agent Client Protocol (ACP)](https://agentclientprotocol.com/). The Copilot CLI runs as a background server shared across all your terminal windows — instant responses, no cold start.

```
You typing:                           What happens:
═══════════                           ════════════
copilot: how do I resize a VMSS?  →   Q&A mode (answer only, no actions)
copilot! fix the failing test     →   Agent mode (can edit files, run commands)
copilot: {                        →   Multiline block mode
  write a function that           →   (keep typing...)
  takes two parameters            →
}                                 →   Submits the full block
```

### Architecture

```
┌─────────────────────────────────────────┐
│  copilot --acp --port 19532             │
│  (persistent background process)        │
│  Handles: auth, models, streaming,      │
│           tool execution, MCP servers   │
└──────────────┬──────────────────────────┘
               │ TCP (JSON-RPC 2.0)
    ┌──────────┼──────────┐
    │          │          │
 Terminal 1  Terminal 2  Terminal 3
 (session A) (session B) (session C)
```

Each terminal gets its own conversation session. The server is shared.

## Prerequisites

- **PowerShell 7.0+** (includes PSReadLine)
- **GitHub Copilot CLI** — [Install guide](https://docs.github.com/copilot/how-tos/copilot-cli)
  ```powershell
  # Verify installation
  copilot --version
  copilot login  # if not already authenticated
  ```

## Installation

```powershell
# Clone and import
git clone <repo-url> C:\git\copilot-terminal
Import-Module C:\git\copilot-terminal\CopilotTerminal\CopilotTerminal.psd1

# Enable the trigger
Enable-CopilotTerminal
```

### Add to Your Profile (Recommended)

Add these lines to your `$PROFILE` for automatic loading:

```powershell
# Add to $PROFILE (safe — never breaks terminal startup)
Import-Module C:\path\to\CopilotTerminal\CopilotTerminal.psd1 -ErrorAction SilentlyContinue
Enable-CopilotTerminal
```

This is safe to add even on machines where the module or Copilot CLI isn't installed — `Enable-CopilotTerminal` emits a one-line warning and returns, never throws.

## Usage

### Q&A Mode (`copilot:`)

For questions. The AI answers but **cannot** run commands or edit files.

```
PS> copilot: what does Get-ChildItem -Recurse do?
PS> copilot: explain this error: "The term 'az' is not recognized"
PS> copilot: how do I filter a list in PowerShell?
```

### Agent Mode (`copilot!`)

For tasks. The AI **can** run commands, edit files, and use tools.

```
PS> copilot! fix the failing test in src/auth.tests.ps1
PS> copilot! add error handling to the export function
PS> copilot! create a .gitignore for a Node.js project
```

### Multiline Block Mode

For complex prompts that span multiple lines:

```
PS> copilot: {
>> write a PowerShell function that
>> takes a path and a pattern
>> and returns matching files with their sizes
>> sorted by size descending
>> }
```

Works with both triggers: `copilot: {` (Q&A) and `copilot! {` (agent).

### Direct Function Call

```powershell
# Q&A mode
Invoke-CopilotQuery -Question "how do I parse JSON in PowerShell?"

# Agent mode
Invoke-CopilotQuery -Question "fix the linting errors" -ApproveTools

# Skip context injection
Invoke-CopilotQuery -Question "what is ACP?" -NoContext

# Use a specific model
Invoke-CopilotQuery -Question "review this code" -Model "claude-sonnet-4"
```

## Configuration

Configuration is stored at `~/.copilot-terminal/config.json`. Defaults are sensible — you don't need to configure anything to get started.

```powershell
# View current effective config (defaults merged with your overrides)
Get-CopilotConfig

# View only your custom overrides
Get-CopilotConfig -Raw

# Change the ACP server port (default: 19532)
Set-CopilotConfig -Port 19533

# Set a preferred model
Set-CopilotConfig -Model "gpt-5.2"

# Enable agent mode by default (tools always approved)
Set-CopilotConfig -AutoApproveTools $true

# Disable git context (for large repos where git status is slow)
Set-CopilotConfig -IncludeGitInfo $false

# Reduce command history sent with queries
Set-CopilotConfig -HistoryCount 3
```

### Default Configuration

```json
{
  "server": { "port": 19532, "autoStart": true },
  "context": {
    "includeHistory": true, "historyCount": 5,
    "includeLastOutput": true, "includeGitInfo": true, "includeOsInfo": true
  },
  "copilot": { "model": "", "extraArgs": [], "autoApproveTools": false }
}
```

## Server Management

The ACP server starts automatically on your first query. You can also manage it manually:

```powershell
# Start the server (idempotent — safe to call if already running)
Start-CopilotServer

# Stop the server
Stop-CopilotServer

# Check if it's running
Test-Connection -TargetName 127.0.0.1 -TcpPort 19532
```

The server runs as a background process and persists across terminal windows. Stopping it disconnects all terminals.

## Context

CopilotTerminal automatically sends shell context with each query so the AI understands your environment:

- **Current directory** and git branch/status
- **Recent command history** (last 5 commands)
- **Last error/exit code**
- **OS and PowerShell version**

Context is sent in a compact format to minimize token usage:
```
[ctx] cwd=C:\git\myproject;git=main+2mod;recent=git status,npm test;last_exit=1;os=Windows;ps=7.4
```

Use `-NoContext` to skip context injection, or configure individual context sources via `Set-CopilotConfig`.

## Disabling

```powershell
# Remove the PSReadLine hook (normal Enter behavior restored)
Disable-CopilotTerminal

# Stop the background server
Stop-CopilotServer
```

## Performance

Use `-Verbose` to see timing:
```
PS> copilot: what is ACP? -Verbose
...response...
VERBOSE: ⏱ TTFT: 340ms | Total: 2.1s | Chars: 450
```

Performance stats from the last query are available via `$script:LastQueryStats` inside the module scope.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Copilot CLI not found" | Install Copilot CLI: `winget install GitHub.CopilotCLI` |
| "Run `copilot login` first" | Authenticate: `copilot login` |
| "PSReadLine module not loaded" | Ensure you're using PowerShell 7+ (not Windows PowerShell 5.1) |
| Server won't start | Check port: `Set-CopilotConfig -Port 19533` |
| Slow git context | Disable it: `Set-CopilotConfig -IncludeGitInfo $false` |

## License

MIT
