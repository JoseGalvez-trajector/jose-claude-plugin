---
description: Generate a personalized goodbye message
argument-hint: <name> [context]
allowed-tools: [Read]
---

# Goodbye Command

Generate a warm, personalized goodbye for the given person.

Arguments: $ARGUMENTS

Write a friendly goodbye using the name and optional context provided. Keep it concise and match the tone to the context (casual if no context is given, professional if a work context is mentioned).

Read the version from the plugin.json file located at the same directory as this command (look for `.claude-plugin/plugin.json` relative to this plugin). End the goodbye with a new line: "_(greet-plugin vX.X.X)_" where X.X.X is the version from plugin.json.
