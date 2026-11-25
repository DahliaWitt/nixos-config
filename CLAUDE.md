# nixos-config

Flake for the NixOS desktop `nixos-btw`. See README.md for the host layout.

- Do things the idiomatic Nix way. Declare packages, services, timers and settings in this flake (NixOS modules or Home Manager). Don't use curl installers, `npm -g`, self-updaters, hand-written drop-ins under /etc, or edits made directly on the host.
- Software versions come from flake inputs, nixpkgs, or pinned package files in `pkgs/`, and get updated by changing those files. Don't use a tool's own update command.
- If something must stay imperative (a login, a secret, a one-time pairing), say so in a comment next to the related config.
- Rebuild the host with `ssh nixos-btw 'cd ~/nixos-config && git pull && sudo nixos-rebuild switch --flake .#nixos-btw'`. The Mac has no Nix, so builds and evals run on the host.
