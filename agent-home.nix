# Home Manager config for the unprivileged `agent` user (see remote.nix).
# Everything here comes from Nix: the agent CLIs, T3 and its service. They
# update when flake.lock and pkgs/ change, not through their own updaters.
# Projects bring their own Playwright and browsers (see nix-ld in remote.nix).
{ pkgs, ... }:
let
  t3Home = "/home/agent/.t3";
in
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # Agent CLIs
    claude-code
    codex
    pi-coding-agent
    cursor-cli
    t3

    git
    gh
    jq
    ripgrep
    fd
    just
    nodejs_22
    pnpm
    python3
    uv
    bubblewrap
  ];

  # kimi, deepseek and glm: wrapper scripts synced from the Mac by
  # scripts/sync-agent-harnesses.sh.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # The T3 service gets PATH from the systemd user manager, not the shell.
  # Named 60- so it runs after NixOS's /etc/environment.d/50-systemd-path.conf.
  xdg.configFile."environment.d/60-agent-path.conf".text = ''
    PATH=/home/agent/.local/bin:''${PATH}
  '';

  # T3 server, mirroring the unit `t3 up` writes, plus the memory protection
  # `t3 service protect` would add (system side in remote.nix): the kernel
  # reclaims and OOM-kills agents before the server.
  systemd.user.services.t3code = {
    Unit = {
      Description = "T3 Code server";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${pkgs.t3}/bin/t3 serve --lan --no-browser";
      WorkingDirectory = "%h";
      Environment = [ "T3CODE_HOME=${t3Home}" ];
      KillMode = "mixed";
      # Helpers share this cgroup; OOMPolicy=stop would stop the server when
      # one of them is OOM-killed.
      OOMPolicy = "continue";
      Restart = "always";
      RestartSec = 5;
      CPUWeight = 1000;
      IOWeight = 1000;
      MemoryLow = "1536M";
      OOMScoreAdjust = -900;
      ManagedOOMPreference = "avoid";
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.slices.app.Slice.MemoryLow = "1536M";
  xdg.configFile."systemd/user/init.scope.d/90-t3code-protect.conf".text = ''
    [Scope]
    MemoryLow=256M
  '';
  # Everything else the user manager starts is the first OOM victim.
  xdg.configFile."systemd/user.conf.d/90-t3code-protect.conf".text = ''
    [Manager]
    DefaultOOMScoreAdjust=200
  '';

  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Dahlia Witt";
      user.email = "dwitt@dranweb.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      # HTTPS auth to GitHub through `gh auth login`.
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  programs.home-manager.enable = true;
}
