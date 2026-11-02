# claude-config

My global Claude Code skills.

## Install

```powershell
git clone https://github.com/ctolkien/claude-config $HOME\source\repos\claude-config
& $HOME\source\repos\claude-config\install.ps1
```

`install.ps1` junctions each folder in `skills/` into `~/.claude/skills/`, so edits here are live immediately. Re-run it after adding a skill.

## Skills

- **address-pr-feedback**: triage review comments on a GitHub PR (Copilot, other bots, humans), fix what's right, reply, and resolve threads. `/address-pr-feedback 943`
