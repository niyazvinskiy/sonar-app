# Sonar 1.4.1 Windows migration fix

2026-11-23: installer waits for the protected Sonar GUI message loop before returning to the legacy updater, including hidden startup. Existing user shortcuts are redirected to the protected installation. Four native startup script tests pass; PowerShell syntax and workflow YAML parse; independent review has no remaining P1/P2. Manual Windows-only release still gates publication on full application tests and native Windows tests and pins tag to the built commit.

Pending: cloud Windows build/publication. User deferred live connection verification with Happ disabled.
