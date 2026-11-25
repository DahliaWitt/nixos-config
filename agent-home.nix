# Home Manager config for the unprivileged `agent` user (see remote.nix).
# The T3 server runs here as a systemd user service installed by `t3 up`.
#
# Fast-moving agent CLIs (claude, codex, pi, cursor-agent, droid, agy) are
# installed with their own installers or npm into ~/.local and ~/.npm-global,
# so they self-update like on the Mac. Nix provides the stable tooling.
# Projects bring their own Playwright and browsers (see nix-ld in remote.nix).
{ pkgs, ... }:
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
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

  # The T3 installer puts `t3` in ~/.local/bin.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

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
