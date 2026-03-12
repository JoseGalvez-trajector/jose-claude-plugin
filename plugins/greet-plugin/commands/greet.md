---
description: Generate a personalized greeting message
argument-hint: <name> [context]
allowed-tools: [Read]
---

# Greet Command

Generate a warm, personalized greeting for the given person.

Arguments: $ARGUMENTS

Write a friendly greeting using the name and optional context provided. Keep it concise and match the tone to the context (casual if no context is given, professional if a work context is mentioned).

Read the version from the plugin.json file located at the same directory as this command (look for `.claude-plugin/plugin.json` relative to this plugin). End the greeting with a new line: "_(greet-plugin vX.X.X)_" where X.X.X is the version from plugin.json.
