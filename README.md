## Dahlia's NixOS Config

Use `nrs` to store and reload changes.

### Remote host

`remote.nix` makes this desktop a remote T3 Code host and agent sandbox:

- Tailscale and SSH are reachable only over the tailnet.
- `dwitt` is the admin user with passwordless sudo, so rebuilds work over SSH.
- `agent` runs T3 Code, coding agents and CI. It has no sudo and uses rootless podman. Its packages live in `agent-home.nix`.
- Suspend is disabled so the machine stays reachable.

One-time setup on the desktop:

1. Run `git pull && nrs`.
2. Run `sudo tailscale up --operator=agent` and log in through the printed URL. The operator flag lets `agent` run `tailscale serve` for T3's HTTPS route.
3. In the Tailscale admin console, disable key expiry for `nixos-btw`.

Then from the MacBook, with `nixos-btw` and `nixos-btw-agent` defined in `~/.ssh/config`:

1. Run `ssh nixos-btw-agent`.
2. Install the CLI with `curl -fsSL https://t3.codes/install.sh | sh`, then run `t3 up`. Choose the local network, which also covers the tailnet, so T3 listens on the Tailscale address.
3. Sign in to each provider as `agent` (`claude`, `codex`, `gh auth login`).
4. Pair the Mac app with `t3 pair`, or with `t3 pair --tailscale` for an HTTPS URL.

Rebuild remotely with `ssh nixos-btw 'cd ~/nixos-config && git pull && nh os switch'`.
