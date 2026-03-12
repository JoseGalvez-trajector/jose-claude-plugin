# Claude Code Plugin Marketplace

A personal marketplace for Claude Code plugins by jose-galvez.

## Structure

```
plugins/
└── greet-plugin/          # Greeting plugin with skill + hooks
    ├── .claude-plugin/
    │   └── plugin.json
    ├── skills/
    │   └── greeting-skill/
    │       └── SKILL.md
    ├── hooks/
    │   ├── hooks.json
    │   ├── pre-tool-use.sh    # Blocks rm -rf commands
    │   └── post-tool-use.sh   # Audit log of tool calls
    └── commands/
        └── greet.md           # /greet <name> command
```

## For Teammates

Follow these steps to install and use the plugins from this marketplace:

### 1. Register the marketplace

Add the following to your `~/.claude/plugins/known_marketplaces.json`:

```json
{
  "jose-plugins": {
    "source": {
      "source": "github",
      "repo": "JoseGalvez-trajector/jose-claude-plugin"
    },
    "installLocation": "/Users/<your-username>/.claude/plugins/marketplaces/jose-plugins",
    "lastUpdated": "2026-03-13T00:00:00.000Z"
  }
}
```

> Replace `<your-username>` with your macOS username.

### 2. Install a plugin

From Claude Code, run:

```
/plugin install greet-plugin@jose-plugins
```

### 3. Use the plugin

Once installed, you can use the greeting skill:

```
/greet-plugin:greeting-skill alex
```

Or greet someone professionally:

```
/greet-plugin:greeting-skill greet alex professionally
```

---

## Local Development

Load a plugin directly without publishing:

```
claude --plugin-dir /Users/jose.galvez/Documents/claude-plugins/plugins/greet-plugin
```
