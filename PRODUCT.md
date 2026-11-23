# Sonar

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Sonar is a native Flutter application with Windows, macOS, Linux, Android and iOS source targets. The approved work recorded here is Windows first; the connection desk adapts to window width rather than adopting web page conventions. This record does not assert that every platform has been built or verified for this release.

## Users

The confirmed Windows workflow is for a person who wants VPN connectivity across their computer, including browsers, games, voice applications and terminal tools. They need to see whether the connection is active, choose routing and a channel, and explicitly stop automatic connection attempts. Broader audience research and market positioning have not been supplied.

## Product Purpose

Provide access through the existing Sonar VPN core with a clear connection action, truthful session measurements and recovery after interruptions. On Windows, support starting after sign-in and connecting automatically, with separate visible controls for both preferences.

## Operating Context

- Flutter and Riverpod drive the native interface and connection state; the repository retains its Hiddify-derived internal package names and native core.
- First-run key issuance obtains a Sonar subscription for the device. Existing profiles, keys and preferences must survive updates.
- Windows VPN mode captures computer traffic through a TUN adapter and requires administrative rights. The approved setup allows one Windows elevation confirmation and later launches through Task Scheduler; UAC must remain enabled.
- A slow or offline network is an expected operating condition. Recovery uses bounded delays and serial attempts, and must not repeatedly change channels merely because a responding connection is slow.
- The built-in updater retrieves releases from `niyazvinskiy/sonar-app`. A release and a live PC update check are authorized for this work; authorization is not evidence that either has succeeded.

## Capabilities and Constraints

- Main actions: connect, stop or disconnect; select a channel; choose smart routing or route traffic through Sonar with the documented Russian-site exception.
- Session details: elapsed connection time, measured latency, download/upload rates and transferred totals. Unavailable measurements use an em dash. A fixture measurement is never proof of live connectivity or throughput.
- Automatic connection and Windows startup are independent preferences. A manual stop cancels recovery. Update or administrator relaunch must preserve the appropriate connection intent rather than forcing a stopped connection on.
- Native network/core operations and update installation must not overlap in ways that restart a manually stopped connection.
- Network availability and bandwidth cannot be guaranteed by the interface or retry logic.
- Manual stop persists for the current Windows boot, including updater/admin relaunch. A new boot restores connection when automatic startup connection is enabled. An explicit updater/admin relaunch resumes a wanted connection even when ordinary startup connection is disabled.

## Brand Commitments

The user approved preserving the Sonar name, dark night-water identity, Jost typography and signature pearl drop while substantially refreshing home and settings. The current surface direction is recorded in `.impeccable/surfaces/windows-connection.md`. UI copy is primarily Russian in the reviewed surface, with familiar action labels and concrete recovery guidance.

## Evidence on Hand

- Approved requirements: `docs/superpowers/specs/2026-11-20-windows-resilience.md`.
- Implementation plan: `docs/superpowers/plans/2026-11-20-windows-resilience.md`.
- Native source: `lib/sonar/sonar_home_view.dart`, `sonar_style.dart`, `sonar_settings.dart`, `sonar_windows_settings.dart`, `sonar_sphere.dart` and `lib/core/theme/app_theme.dart`.
- Seven reviewed PNG fixtures in `.impeccable/review/`: desktop connected, small connected, enlarged-text connected, idle, connecting, failed and settings. They are Flutter widget-test captures made with synthetic states, telemetry and package version; they are not screenshots of an installed app connected to the live VPN.
- `test/sonar/sonar_home_layout_test.dart` covers callback wiring, scroll reachability at narrow width and enlarged text, reduced motion and settings wrapping. Test source is a specification; a passing run must be reported from actual execution output.
- No testimonials, customer counts, speed guarantees or independent availability evidence have been supplied.

## Product Principles

1. Connection state and the user's action lead; routing and measurements follow.
2. Automatic behavior remains visible, controllable and subordinate to a manual stop.
3. Represent failures, pending work and unavailable measurements honestly.
4. Preserve keys and preferences through setup, recovery and updates.
5. Verify live installed behavior separately from synthetic UI fixtures and isolated tests.

## Accessibility & Inclusion

The approved requirements include small Windows windows, enlarged text and reduced motion. Essential connection and route actions must remain reachable by scrolling. Native buttons, switches, focus behavior and icon affordances should remain usable by keyboard. Text communicates state in addition to the drop's color; the connection status is a live semantic region and the ornamental duplicate drop action is excluded from semantics.
