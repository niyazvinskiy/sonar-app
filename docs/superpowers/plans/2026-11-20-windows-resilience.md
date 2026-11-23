# Sonar Windows Resilience Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task.

**Goal:** Automatic Windows startup/connection, resilient recovery, refreshed Sonar UI and a verified GitHub update.

**Architecture:** Existing Flutter/Riverpod core with a persistent connection-intent/retry controller, Windows scheduled task and current GitHub updater. Preserve native VPN core and user profile data.

**Tech Stack:** Flutter 3.38.5, Dart, Riverpod, Windows Task Scheduler, Inno Setup, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-11-20-windows-resilience.md

## Global Constraints

- One elevation confirmation is acceptable; never disable UAC.
- Manual stop cancels reconnection. No overlapping connection attempts.
- Keep dark Sonar identity and drop. Maintain profile and user settings.
- Publish is explicitly authorized by the user.

## Review Focus

- Offline startup: retry with backoff and recover without busy looping.
- Manual stop during retry: stay stopped, including queued timers.
- Slow connection: tolerate latency without repeatedly switching channels.
- Update on an elevated app: preserve user identity, install path, startup task and reconnect intent.
- UI at small Windows size and enlarged text: no hidden essential actions.

### Task 1: Connection recovery
- [x] Add tests for backoff, cancellation, startup and retry serialization.
- [x] Implement controller and integrate home connection intent, strengthen channel guard concurrency and slow-link tolerance.
- [x] Run focused tests and analyzer.

### Task 2: Interface
- [x] Inspect current UI and design context, document surface direction.
- [x] Redesign home and settings presentation preserving APIs and dark drop identity.
- [x] Verify widget tests and captures, including small layout.

### Task 3: Windows automation and updater
- [x] Test scheduled-task script generation and failure paths.
- [x] Add logon-trigger task, explicit startup control and reliable administration detection.
- [x] Strengthen updater download/integrity/install/relaunch; validate existing update path.
- [ ] Run Windows tests, build, review combined changes, release and verify installed update.
