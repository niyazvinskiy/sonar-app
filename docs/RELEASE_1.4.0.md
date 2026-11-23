# Sonar 1.4.0 verification

2026-11-23: full Windows Flutter test suite passed: 264 tests, 20 intentionally skipped screenshot fixtures. Targeted Dart analysis passed. Code review blockers addressed: SID-scoped protected startup tasks, protected verified updater staging, installer shutdown race, and preserving explicit relaunch intent with automatic startup disabled.

Published 2026-11-23: Windows and Android assets; Windows cloud packaging/native tests and Linux-hosted application tests passed. Linux AppImage packaging failed on file permissions; macOS runner was not allocated. Live PC: old 1.3.2 downloaded and installed 1.4.0 into Program Files and created the SID task. Legacy relaunch won the first-start race; launching the SID task switched to 1.4.0. Live connection encountered a TUN IPv4 conflict while Happ was also open; user chose to check connection later. Migration-race packaging fix follows in 1.4.1. Synthetic screenshots are UI evidence only.
