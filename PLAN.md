# Copilot Terminal — PowerShell Module Plan

## Problem
Create a PowerShell module that lets users type normally in their terminal, but when they prefix a line with `copilot:`, the text is intercepted and sent to a persistent GitHub Copilot CLI agent via the Agent Client Protocol (ACP). The copilot agent runs as a singleton background process shared across all terminal windows, providing instant responses with shared conversation memory.

## Approach
Build a PowerShell 7+ module (`CopilotTerminal`) that:
1. Hooks PSReadLine's `Enter` key to detect the `copilot:` trigger
2. Auto-starts a `copilot --acp --port <port>` background server on first query
3. Communicates via JSON-RPC 2.0 over TCP (NDJSON framing)
4. Shares the server across all PowerShell terminals = shared memory, instant responses

The Copilot CLI handles auth, model selection, tool execution, and rendering. We handle the PSReadLine hook, context injection, server lifecycle, and ACP client protocol.

## Architecture — Data Flow
```
                     ┌─────────────────────────────────────────────┐
                     │   copilot --acp --port 19532                │
                     │   (persistent background process)           │
                     │                                             │
                     │   Handles: auth, models, streaming,         │
                     │            tool execution, MCP servers      │
                     │                                             │
                     │   Sessions:                                 │
                     │     session-abc (Terminal 1, Q&A mode)      │
                     │     session-def (Terminal 2, agent mode)    │
                     │     session-ghi (Terminal 3, Q&A mode)      │
                     └────────────┬────────────────────────────────┘
                                  │ TCP :19532 (JSON-RPC 2.0 / NDJSON)
                     ┌────────────┼────────────┐
                     │            │            │
              Terminal 1    Terminal 2    Terminal 3
              (PS 7.4)      (PS 7.4)      (PS 7.4)
                │
                │  copilot: how do I fix this test?    ← Q&A mode (tools denied)
                │  copilot! go fix this test           ← Agent mode (tools approved)
                │  copilot: {\n  multiline\n}          ← Block prompt
                ▼
    ┌───────────────────────────────┐
    │  PSReadLine Enter Hook         │
    │  Detects prefix:               │
    │    copilot:  → Q&A mode        │
    │    copilot!  → Agent mode      │
    │    copilot: { → Block open     │
    │  → $script:_copilotPending     │  (1B: script-scoped var)
    │  → Invoke-CopilotQuery         │
    └───────────┬───────────────────┘
                │
                ▼
    ┌───────────────────────────────┐
    │  Invoke-CopilotQuery           │
    │  1. Get-CopilotConfig          │
    │  2. Start-CopilotServer        │──→ Is :19532 listening? No → start background copilot --acp
    │  3. Connect-AcpServer          │──→ TCP connect + initialize (version check!) + session/new
    │  4. Get-ShellContext            │──→ structured context as system message
    │  5. Send-AcpPrompt             │──→ session/prompt via JSON-RPC
    │  6. Measure-QueryPerformance   │──→ time-to-first-token + total (verbose output)
    └───────────┬───────────────────┘
                │
                ▼
    ┌───────────────────────────────┐
    │  ACP Protocol Flow             │
    │                                │
    │  → session/prompt {            │
    │      sessionId: "abc-123",     │
    │      prompt: [                 │
    │        { type: "text",         │
    │          text: "user question" │
    │        }                       │
    │      ]                         │
    │    }                           │
    │                                │
    │  ← session/update (streaming)  │
    │    { agent_message_chunk,      │
    │      content: { text: "..." }} │──→ Write-Host (real-time)
    │    ...repeats...               │
    │                                │
    │  ← prompt result               │
    │    { stopReason: "end_turn" }  │
    │                                │
    │  ← session/request_permission  │
    │    (if agent wants to run      │
    │     tools / edit files)        │──→ Q&A mode: DENY
    │                                │    Agent mode: APPROVE
    └───────────────────────────────┘
```

### What we build vs. what Copilot CLI handles
```
We build:                              Copilot CLI (ACP server) handles:
════════                               ═══════════════════════════════════
PSReadLine hook (trigger)              Authentication (GitHub/MS login)
ACP JSON-RPC client (TCP)              AI model selection + API calls
Server lifecycle (start/stop/detect)   Streaming responses
Session management (per terminal)      Tool execution (file edits, commands)
Shell context gathering                MCP server integration
Config (port, context toggles)         Markdown rendering
```

## Module Structure
```
CopilotTerminal/
├── CopilotTerminal.psd1              # Module manifest (PS 7.0+ required)
├── CopilotTerminal.psm1              # Loader: dot-sources w/ try/catch per file (8A)
├── Public/
│   ├── Invoke-CopilotQuery.ps1       # Build prompt, send via ACP, stream response
│   ├── Enable-CopilotTerminal.ps1    # Hook PSReadLine (checks PSReadLine + copilot installed)
│   ├── Disable-CopilotTerminal.ps1   # Remove the PSReadLine hook
│   ├── Start-CopilotServer.ps1       # Ensure ACP server running (auto-start or manual)
│   ├── Stop-CopilotServer.ps1        # Stop background ACP server
│   ├── Set-CopilotConfig.ps1         # Write config values
│   └── Get-CopilotConfig.ps1         # Read + merge config (JSON > defaults)
├── Private/
│   ├── Connect-AcpServer.ps1         # TCP connect + JSON-RPC initialize + session/new
│   ├── Send-AcpPrompt.ps1            # session/prompt + handle streaming updates + permissions
│   └── Get-ShellContext.ps1          # Gather cwd, git (fast), history, OS info
├── Config/
│   └── default-config.json           # Ships with module as defaults
├── Tests/
│   ├── CopilotTerminal.Tests.ps1     # Module load, exports, server lifecycle
│   ├── Config.Tests.ps1              # JSON merge, malformed file, defaults
│   ├── AcpClient.Tests.ps1           # JSON-RPC framing, message building, mock server
│   └── Context.Tests.ps1             # Git/no-git, history, OS info
├── README.md
└── .gitignore
```

**17 files total.**

## Todos

### 1. scaffold — Project scaffolding & module manifest
Create the directory tree, `.psd1` manifest (PowerShellVersion = '7.0'), `.psm1` loader with try/catch per dot-source file (8A), module-scoped state variables (`$script:AcpConnection`, `$script:SessionId`), `.gitignore`, and `README.md` stub.

### 2. config — Configuration system
- `default-config.json` with server port, context toggles, copilot CLI flags
- `Get-CopilotConfig.ps1` (public) — loads JSON file → defaults, merges and returns (6A)
- `Set-CopilotConfig.ps1` — creates/updates `~/.copilot-terminal/config.json`
- Config schema:
  ```json
  {
    "server": {
      "port": 19532,
      "autoStart": true
    },
    "context": {
      "includeHistory": true, "historyCount": 5,
      "includeLastOutput": true,
      "includeGitInfo": true,
      "includeOsInfo": true
    },
    "copilot": {
      "model": "",
      "extraArgs": [],
      "autoApproveTools": false
    }
  }
  ```
  - `server.port` — default 19532 (high range, avoids dev server collisions)
  - `copilot.autoApproveTools` — **defaults to `false`** (Q&A mode). `copilot!` trigger overrides to true per-query. Users can set `true` globally via config.
- **Depends on**: scaffold

### 3. server — ACP server lifecycle (`Start-CopilotServer.ps1`, `Stop-CopilotServer.ps1`)
Manage the persistent `copilot --acp --port <port>` background process:
- `Start-CopilotServer`:
  - Check if port is already listening (try TCP connect)
  - If not → start `copilot --acp --port $port` as detached background process (no `--allow-all` on server; permission decisions are made client-side per-query)
  - Wait up to 10s for port to become available (poll every 500ms)
  - Store PID in `~/.copilot-terminal/server.pid` for later cleanup
  - Idempotent — safe to call multiple times
- `Stop-CopilotServer`:
  - Read PID from `server.pid`, send termination signal
  - Clean up pid file
- **Error handling**:
  - `copilot` not on PATH → "Copilot CLI not found. Install: https://docs.github.com/copilot/how-tos/copilot-cli"
  - `copilot` not authenticated → "Run `copilot login` first"
  - Port already in use by non-copilot process → "Port $port in use. Change with Set-CopilotConfig -Port <n>"
  - Server fails to start within 10s → show copilot stderr output
- **Depends on**: config

### 4. acp-client — ACP protocol client (`Connect-AcpServer.ps1`, `Send-AcpPrompt.ps1`)
JSON-RPC 2.0 client over TCP with NDJSON framing:
- `Connect-AcpServer`:
  - `[System.Net.Sockets.TcpClient]` → connect to `localhost:<port>`
  - `StreamReader` + `StreamWriter` for NDJSON (one JSON object per line)
  - Send `initialize` JSON-RPC request:
    ```json
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{
      "protocolVersion":"2025-XX","clientCapabilities":{}
    }}
    ```
  - **Protocol version check**: Read the `initialize` response's `serverCapabilities` and `protocolVersion`. If the returned version doesn't match our expected version, emit `Write-Warning "ACP protocol version mismatch (server: $theirs, expected: $ours). Some features may not work. Update CopilotTerminal module."`. Continue anyway (best-effort), don't hard-fail.
  - Send `session/new`:
    ```json
    {"jsonrpc":"2.0","id":2,"method":"session/new","params":{
      "cwd":"C:\\git\\myproject","mcpServers":[]
    }}
    ```
  - Store connection + sessionId in `$script:AcpConnection` / `$script:SessionId`
  - Connection is per-terminal (each PS window gets its own session)
- `Send-AcpPrompt`:
  - Send `session/prompt`:
    ```json
    {"jsonrpc":"2.0","id":N,"method":"session/prompt","params":{
      "sessionId":"abc-123",
      "prompt":[{"type":"text","text":"<context + question>"}]
    }}
    ```
  - Read NDJSON lines from stream:
    - `session/update` notifications with `agent_message_chunk` → `Write-Host` chunk text
    - `session/request_permission`:
      - **Q&A mode** (`copilot:`) → return `{ outcome: "cancelled" }` (deny tools)
      - **Agent mode** (`copilot!`) → return `{ outcome: "approved" }` (allow tools)
      - Controlled by `$ApproveTools` parameter passed from `Invoke-CopilotQuery`
    - Prompt result with `stopReason` → return
  - **Connection loss handling**: If TCP drops mid-query:
    1. Show partial response received so far (don't lose it)
    2. `Write-Warning "⚠ Connection to Copilot lost. Session history preserved on server."`
    3. On next query: reconnect TCP, attempt `session/load` with the old sessionId first
    4. If `session/load` fails (server restarted) → `session/new` + `Write-Warning "Previous session unavailable. Starting fresh."`
    5. Never silently lose context — always tell the user what happened
- **Depends on**: config, server

### 5. context — Shell context gatherer (`Get-ShellContext.ps1`)
Collects context to include with the AI prompt. Returns a **structured, compact format** to minimize token usage:
- **Current directory** + git info using fast commands (12A): `git rev-parse --abbrev-ref HEAD` + `git status --porcelain -uno` with 1-second timeout
- **Recent command history** (last N commands from `Get-History`)
- **Last command output** — capture via `$Error[0]` and exit codes
- **OS & shell info** — `$PSVersionTable`, `$env:OS`, terminal host
- Returns a compact key-value string (not prose — saves tokens):
  ```
  cwd=C:\git\myproject;git=main+2mod;last_exit=1;last_err=npm ERR! Test failed;os=Win11;ps=7.4.6;recent=Get-ChildItem,git status,npm test
  ```
- Context is sent as a **separate text block** in the ACP prompt array, before the user's question:
  ```json
  "prompt": [
    { "type": "text", "text": "[ctx] cwd=C:\\git\\myproject;git=main+2mod;..." },
    { "type": "text", "text": "how do I fix this test?" }
  ]
  ```
  This keeps context distinct from the question, and the ACP server can potentially interpret the prompt array more intelligently than a single concatenated string.
- **Depends on**: scaffold

### 6. query — Core query function (`Invoke-CopilotQuery.ps1`)
```powershell
Invoke-CopilotQuery [-Question] <string> [-NoContext] [-Model <string>] [-ApproveTools]
```
- `-ApproveTools` — agent mode: auto-approve tool permissions. Set by `copilot!` trigger or config `autoApproveTools`.
- Ensures ACP server running (`Start-CopilotServer` if `autoStart`)
- Connects if not connected (`Connect-AcpServer` — lazy, once per terminal)
- Gathers context (`Get-ShellContext` unless `-NoContext`)
- Sends prompt via `Send-AcpPrompt` with `-ApproveTools` flag
- **Performance tracking**: Records `$stopwatch` timestamps:
  - Query start → time-to-first-token (TTFT) → total response time
  - On `-Verbose`: outputs `"⏱ TTFT: 340ms | Total: 2.1s | Tokens streamed: ~150"`
  - Always available via `$script:LastQueryStats` for debugging
- Streaming output appears in real-time via `Write-Host` in the prompt handler
- **Error handling**:

| Failure | User sees |
|---|---|
| `copilot` not installed | "Copilot CLI not found. Install: ..." |
| Server not running + autoStart off | "Copilot server not running. Run Start-CopilotServer or set autoStart=true" |
| Not authenticated | "Run `copilot login` first" |
| TCP connection lost mid-query | See connection loss handling in §4 |
| Empty question (bare `copilot:`) | Show brief help: usage, server status, session info, both trigger modes |

- **Depends on**: config, server, acp-client, context

### 7. hook — PSReadLine integration (`Enable/Disable-CopilotTerminal.ps1`)
- `Enable-CopilotTerminal`:
  - Checks PSReadLine loaded + `copilot` on PATH
  - **$PROFILE hygiene**: If PSReadLine isn't loaded or copilot isn't found, emit a single `Write-Warning` line and return — never throw, never show a stack trace, never break terminal startup.
  - **Dual triggers + multiline support** via PSReadLine `Enter` override:
  ```powershell
  Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
      $line = $null
      [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$null)

      # Multiline block: copilot: { opens, } closes
      if ($script:_copilotBlockMode) {
          if ($line -match '^\s*\}\s*$') {
              # Block close — submit accumulated prompt
              $script:_copilotBlockMode = $false
              $script:_copilotPendingQuestion = $script:_copilotBlockBuffer
              $script:_copilotBlockBuffer = ''
              [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
              [Microsoft.PowerShell.PSConsoleReadLine]::Insert(
                  'Invoke-CopilotQuery -Question $script:_copilotPendingQuestion')
              [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
          } else {
              # Accumulate block line
              $script:_copilotBlockBuffer += "`n$line"
              [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
              [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
          }
      }
      # Block open: copilot: {
      elseif ($line -match '^copilot[:\!]\s*\{\s*$') {
          $script:_copilotBlockMode = $true
          $script:_copilotBlockBuffer = ''
          $script:_copilotApproveTools = ($line -match '^copilot!')
          [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
          [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
          # TODO: change prompt to indicate block mode (e.g., "copilot> ")
      }
      # Agent mode: copilot! <question> (tools approved)
      elseif ($line -match '^copilot!\s*(.+)$') {
          $script:_copilotPendingQuestion = $Matches[1]
          [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
          [Microsoft.PowerShell.PSConsoleReadLine]::Insert(
              'Invoke-CopilotQuery -Question $script:_copilotPendingQuestion -ApproveTools')
          [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
      }
      # Q&A mode: copilot: <question> (tools denied)
      elseif ($line -match '^copilot:\s*(.+)$') {
          $script:_copilotPendingQuestion = $Matches[1]
          [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
          [Microsoft.PowerShell.PSConsoleReadLine]::Insert(
              'Invoke-CopilotQuery -Question $script:_copilotPendingQuestion')
          [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
      }
      # Empty copilot: → help
      elseif ($line -match '^copilot[:\!]\s*$') {
          [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
          [Microsoft.PowerShell.PSConsoleReadLine]::Insert(
              'Invoke-CopilotQuery -Question ""')
          [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
      }
      # Normal command — pass through
      else {
          [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
      }
  }
  ```
- `Disable-CopilotTerminal` — restores default `AcceptLine` handler, clears block mode state
- **Depends on**: query

### 8. tests — Pester tests (4 test files)
- `CopilotTerminal.Tests.ps1` — module loads silently (no errors even if copilot missing), exports expected functions, Enable-CopilotTerminal degrades to warning (not throw) when prerequisites missing, server start/stop lifecycle, idempotent start
- `Config.Tests.ps1` — JSON merge with defaults, missing config → defaults (port 19532, autoApproveTools false), malformed JSON → error, Set-CopilotConfig round-trip, port config
- `AcpClient.Tests.ps1` — JSON-RPC message building (correct NDJSON framing), initialize handshake, **protocol version mismatch warning** (doesn't hard-fail), session creation, prompt sending with Q&A vs agent mode permission handling, streaming update parsing, connection loss → session/load retry → fallback to session/new with user warning
- `Context.Tests.ps1` — in-git-repo, not-in-repo skip, git timeout, history collection, OS info, **compact format** (key=value;key=value), prompt array has context as separate block
- Manual test script for PSReadLine hook
- **Depends on**: all above

### 9. docs — README and profile integration guide
- Prerequisites: PowerShell 7+, Copilot CLI installed + authenticated
- How to install + add to `$PROFILE` (safe — never breaks terminal startup):
  ```powershell
  Import-Module CopilotTerminal -ErrorAction SilentlyContinue
  Enable-CopilotTerminal  # warns if prerequisites missing, never throws
  ```
- **Two trigger modes**:
  - `copilot: <question>` — Q&A mode (tools denied, safe for quick questions)
  - `copilot! <command>` — Agent mode (tools approved, full agent powers)
  - `copilot: {` / `}` — Multiline block prompt
- How it works (ACP server, shared across terminals, per-terminal sessions)
- Server management (`Start-CopilotServer`, `Stop-CopilotServer`)
- Context customization (what gets sent, format, how to disable)
- Model selection, extra args, performance verbose output
- **Depends on**: all above

## Key Design Decisions
1. **ACP server mode** — persistent `copilot --acp --port 19532` background process. Instant responses (no cold start), shared infrastructure across terminals, proper session management. Port 19532 (high range) avoids collisions with dev servers.
2. **Auto-start on first query** — server starts lazily, no manual setup needed. Detects existing server to avoid duplicates.
3. **Session per terminal** — each PowerShell window gets its own ACP session, with its own conversation history. Server is shared, sessions are isolated.
4. **Dual trigger modes** — `copilot:` for Q&A (tools denied, `autoApproveTools: false` default), `copilot!` for full agent mode (tools approved). Most inline queries are questions, not commands. Power users can flip the default via config.
5. **Multiline prompts** — `copilot: {` opens block mode, `}` closes and submits. Supports complex multi-line questions.
6. **PSReadLine hook with script-scoped variable** (1B) — avoids quote injection, non-invasive.
7. **$PROFILE safety** — module import and `Enable-CopilotTerminal` never throw. Missing prerequisites get a one-line warning, terminal startup continues normally.
8. **Protocol version resilience** — `initialize` response's `protocolVersion` is checked. Mismatch emits a warning but doesn't hard-fail. Best-effort forward compatibility.
9. **Connection loss transparency** — TCP drops show partial response + explicit warning. Reconnect attempts `session/load` before falling back to `session/new`. User always knows what happened.
10. **Structured context** — compact key=value format in a separate prompt array block. Saves tokens vs. prose, keeps context distinct from question.
11. **Performance tracking** — `Measure-Command` wrapper records TTFT and total time. `-Verbose` shows timing. `$script:LastQueryStats` for debugging.
12. **PS 7+ only** (4A) — clean TcpClient, modern terminal features.
13. **Fast git commands with timeout** (12A) — keeps context gathering sub-second.
14. **Try/catch per dot-source** (8A) — resilient module loader.

## TODOS.md — Deferred Work

### 1. Shared Sessions
**What:** Allow multiple terminals to share the same ACP session (shared conversation memory).
**Why:** Current design gives each terminal its own session. Some users may want a single conversation spanning all windows.
**Context:** Add `Set-CopilotConfig -SharedSession $true`. Store the shared sessionId in `~/.copilot-terminal/session.json`. On connect, load existing session via `session/load` instead of `session/new`.
**Depends on:** Core module.

### 2. Additional Providers (OpenAI, Anthropic, Ollama)
**What:** Support direct API calls as alternatives to the Copilot CLI ACP server.
**Why:** Users without Copilot access, or who prefer a specific provider.
**Context:** Add a `provider` config key. When set to `openai`/`anthropic`/`ollama`, bypass ACP and make direct API calls (original plan architecture). The design work is already done from the review.
**Depends on:** Core module.

### 3. Auto-Suggest Commands
**What:** Parse copilot's streamed output for code blocks, offer to run them.
**Why:** Reduces copy-paste friction.
**Context:** Capture `agent_message_chunk` text, detect fenced code blocks, present as numbered options after response completes. Note: with `autoApproveTools`, copilot may already execute commands via tool calls.
**Depends on:** Core module.

### 4. Tab Completion
**What:** Argument completers for module commands.
**Why:** Discoverability.
**Context:** Complete `-Model` from copilot's supported models list, complete config keys.
**Depends on:** Config system.
