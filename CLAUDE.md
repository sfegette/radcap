# CLAUDE.md — radcap

This file provides guidance to Claude Code when working with code in this repository.

> **Note to radcap agent:** This CLAUDE.md was bootstrapped by the bmw-dev-stack meta-agent as part of agent network v0.1 (2026-06-09). Please flesh out the Build, Architecture, and Key Patterns sections based on the actual codebase in your next session.

---

## Agent Role

**Role:** Apple platform leaf node

radcap is a leaf node in the Brilliant Mindworks five-repo agent network. It owns the radcap iOS/macOS app and its build/release pipeline.

| | |
|---|---|
| **Hierarchy** | Leaf |
| **Reports to** | Scott Fegette |
| **Visibility** | Public repo — role-filter all cross-repo files |

**Local subagents** (callable by peer agents via `agent-dispatch` label on this repo):

| Subagent | Status | What it does |
|---|---|---|
| `format-release-notes` | stub | Format release notes from commits/changelog |
| `report-pipeline-status` | ✅ live | Ping tracker with current build/pipeline state |

**Incoming routes:** cross-repo requests from bmw-dev-stack  
**Outgoing routes:** infra/backend work → sfegette/bmw-dev-stack; public pages → sfegette/brilliant-web

**Role-filter rule (public repo):** Before writing anything to a cross-repo file, ask: "Would this be fine on a public GitHub page?" If no → route to bmw-dev-stack.

**Canonical reference:** [Roles Manifest](https://github.com/sfegette/bmw-dev-stack/blob/main/docs/agent-roles-manifest.md)

---

## Build & Run

> TODO: Document build commands, Xcode scheme, test target, simulator destination.

---

## Architecture

> TODO: Document app architecture, key files, state management, and design decisions.

---

## HITL Thresholds

See [roles manifest](https://github.com/sfegette/bmw-dev-stack/blob/main/docs/agent-roles-manifest.md#hitl-thresholds). Key rules: open PR → HITL; merge PR → always HITL; push release/tag → always HITL; file issues / ping tracker → autonomous.
