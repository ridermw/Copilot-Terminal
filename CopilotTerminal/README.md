# CopilotTerminal

Inline GitHub Copilot integration for PowerShell — ask questions and run agent tasks without leaving your terminal.

> ⚠️ **Under construction** — this module is in early development.

## Prerequisites

- **PowerShell 7.0+** with PSReadLine
- **GitHub Copilot CLI** (`github-copilot-cli` or Copilot extension for `gh`)

## Quick Start

```powershell
Import-Module ./CopilotTerminal
Enable-CopilotTerminal
```

## Usage

### Q&A mode — `copilot:`

Type `copilot:` followed by your question to get an answer inline:

```
copilot: how do I list all stopped services?
```

### Agent mode — `copilot!`

Type `copilot!` followed by a task to let Copilot run tools on your behalf:

```
copilot! find large log files and compress them
```

### Multiline block mode

Wrap longer prompts in braces:

```
copilot: {
  Explain the difference between
  Get-Process and Get-CimInstance Win32_Process,
  and when to use each.
}
```

## Configuration

```powershell
Get-CopilotConfig            # show merged config
Set-CopilotConfig -Port 9999 # change ACP server port
```
