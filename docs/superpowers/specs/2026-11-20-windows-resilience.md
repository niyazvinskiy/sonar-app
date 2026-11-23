# Sonar Windows: automatic connection and refreshed interface

Approved by the user in chat on 2026-11-20: preserve dark Sonar identity and drop, substantially redesign home/settings, enable startup and automatic connection, reconnect until manually stopped. One Windows elevation confirmation during configuration is acceptable; subsequent starts must not ask again.

Use Flutter/Riverpod and the existing native VPN core. Register an interactive scheduled task for the current user, highest privileges, logon trigger and no runtime limit. Do not disable UAC. Keep a visible opt-out for startup and connection. Retry with bounded backoff, one connection attempt at a time; manual disconnect cancels recovery. Avoid channel churn on a slow but responding connection. Handle offline startup, sleep/wake, missing profile and failure honestly.

Design: clear connection status, prominent drop action, readable connection metrics, compact route/channel controls and explicit automation settings. Respect small windows and text scaling; reduce motion when requested.

Release only after meaningful tests/analyzer/build checks. Verify actual installed Windows version, update download/install/relaunch and preference preservation. Report live tests separately from simulated/unit coverage. No promise can create bandwidth or connectivity when the network has none.
