## Dahlia's NixOS Config

Use `nrs` to store and reload changes.

### Remote host

`remote.nix` makes this desktop a remote T3 Code host and agent sandbox:

- Tailscale and SSH are reachable only over the tailnet. SSH is key-only.
- `dwitt` is the admin user with passwordless sudo, so rebuilds work over SSH.
- `agent` runs T3 Code, coding agents and CI. It has no sudo and uses rootless podman. Its Nix packages live in `agent-home.nix`. The agent CLIs (claude, codex, pi, cursor-agent, t3) are self-installed in `~/.local/bin` and `~/.npm-global` so they update themselves.
- autosuspend sleeps the box after 20 idle minutes. Idle means no SSH session, no local desktop use, low load, and agent processes near 0% CPU. Plasma's own idle suspend is off.
- Wake-on-LAN works over Wi-Fi and Ethernet. On the Mac, `~/.local/bin/wake-desktop` sends the magic packet from whiterose, and `~/.ssh/config` runs it before every `ssh nixos-btw*`.

T3 runs as a systemd user service for `agent` (`t3 up --lan`). It serves on `https://nixos-btw.taile451e0.ts.net` (Tailscale Serve) and on port 3773 over the tailnet. Update it with `t3 update` as `agent`, not through Nix.

`scripts/sync-agent-harnesses.sh` mirrors the Mac's harness setup to `agent`: aihub rules and skill repos, `~/.agents/skills`, Claude/Codex/Pi config and plugins, the kimi/deepseek/glm wrappers, and logins. Re-run it after changing skills or config on the Mac. `NO_CREDS=1` skips the logins.

Rebuild remotely with `ssh nixos-btw 'cd ~/nixos-config && git pull && sudo nixos-rebuild switch --flake .#nixos-btw'`.
