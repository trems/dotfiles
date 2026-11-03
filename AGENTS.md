# Workspace Guidelines

## Network & Diagnostic Command Guardrails
- **Always specify explicit timeouts** for any network diagnostic commands, especially when testing proxies, VPNs, tunnels, remote SSH connections, or container endpoints.
  - **curl**: Always include `--max-time <seconds>` (e.g. 5–15s) and `--connect-timeout <seconds>` (e.g. 3–5s) to avoid hanging commands on unreachable or slow endpoints.
  - **ssh**: Always include `-o ConnectTimeout=<seconds>` (e.g. 5s) and `-o BatchMode=yes` where non-interactive.
  - Never run unbounded network probe loops or requests without per-request timeout limits.

## NixOS & Infrastructure Invariants
- **NixOS configuration is the single source of truth**:
  - Always inspect the Nix flake and host modules (`flake.nix`, `hosts/`, `services/`) to discover host definitions, open ports, container configurations, and service parameters dynamically.
  - Do not hardcode or assume static hostnames, ports, node lists, or paths across machines.
