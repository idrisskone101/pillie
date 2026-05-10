---
name: superdesign
description: Use before implementing Pillie UI work that needs design thinking, design-system decisions, flow/page design, or visual iteration with the Superdesign CLI.
metadata:
  author: superdesign
  version: "0.0.1"
---

# Superdesign

Use this skill before implementing UI that needs design thinking, a design-system pass, or visual alternatives. In this repo it is especially useful before SwiftUI screens, onboarding/paywall changes, and any flow where layout, hierarchy, or interaction details matter.

## Core Scenarios

1. Design a new feature, page, screen, or flow.
2. Establish or adjust a design system.
3. Improve an existing design.
4. Generate or iterate design drafts before writing production UI code.

## Workflow

1. Read the relevant existing UI code and screenshots if available.
2. Create or reuse a Superdesign project for the task.
3. Generate one faithful draft when starting from existing UI.
4. Iterate drafts for requested visual direction or UX changes.
5. Translate the selected design into production code using the repo's existing SwiftUI patterns.
6. Verify in the simulator with screenshots after implementation.

## CLI

Install and authenticate if needed:

```bash
npm install -g @superdesign/cli@latest
superdesign login
superdesign --help
```

Common commands:

```bash
superdesign create-project --title "Pillie UI"
superdesign create-design-draft --project-id <id> --title "Current UI" -p "Faithfully reproduce this screen." --context-file Pillie/Pillie/Views/SomeView.swift
superdesign iterate-design-draft --draft-id <id> -p "Make the layout calmer and more task-focused." --mode branch --context-file Pillie/Pillie/Views/SomeView.swift
superdesign execute-flow-pages --draft-id <id> --pages '[...]' --context-file Pillie/Pillie/Views/SomeView.swift
```

Context files may include line ranges, for example:

```bash
--context-file Pillie/Pillie/Views/SomeView.swift:40:180
```

## Fresh Guidelines

When detailed Superdesign behavior is needed and network access is available, fetch the official current guidance from:

```text
https://raw.githubusercontent.com/superdesigndev/superdesign-skill/main/skills/superdesign/SUPERDESIGN.md
```

Load only the parts needed for the current task.
