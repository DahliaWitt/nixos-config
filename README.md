## Dahlia's NixOS Config

Use `nrs` to store and reload changes.

### Remote host

`remote.nix` makes this desktop a remote T3 Code host and agent sandbox:

- Tailscale and SSH are reachable only over the tailnet. SSH is key-only.
- `dwitt` is the admin user with passwordless sudo, so rebuilds work over SSH.
- `agent` runs T3 Code, coding agents and CI. It has no sudo and uses rootless podman. `agent-home.nix` declares its packages, including the agent CLIs (claude, codex, pi, cursor-agent, t3), and the T3 service.
- autosuspend sleeps the box after 20 idle minutes. Idle means no SSH session, no local desktop use, low load, and agent processes near 0% CPU. Plasma's own idle suspend is off.
- Wake-on-LAN works over Wi-Fi and Ethernet. On the Mac, `~/.local/bin/wake-desktop` sends the magic packet from whiterose, and `~/.ssh/config` runs it before every `ssh nixos-btw*`.

T3 runs as the `t3code` systemd user service for `agent`, declared in `agent-home.nix`, with the memory protection `t3 service protect` would add declared across `agent-home.nix` and `remote.nix`. It serves on `https://nixos-btw.taile451e0.ts.net` (Tailscale Serve) and on port 3773 over the tailnet. The version is pinned in `pkgs/t3.nix`. Don't use `t3 update` or `t3 service`.

`pkgs/update.sh` runs `nix flake update` and bumps `pkgs/t3.nix` to the latest stable T3 release. Run it on the host, then rebuild.

`scripts/sync-agent-harnesses.sh` mirrors the Mac's harness setup to `agent`: aihub rules and skill repos, `~/.agents/skills`, Claude/Codex/Pi config and plugins, the kimi/deepseek/glm wrappers, and logins. Re-run it after changing skills or config on the Mac. `NO_CREDS=1` skips the logins.

Rebuild remotely with `ssh nixos-btw 'cd ~/nixos-config && git pull && sudo nixos-rebuild switch --flake .#nixos-btw'`.
