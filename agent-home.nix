# Home Manager config for the unprivileged `agent` user (see remote.nix).
# The T3 server runs here as a systemd user service installed by `t3 up`.
#
# Fast-moving agent CLIs (claude, codex, pi, cursor-agent, droid, agy) are
# installed with their own installers or npm into ~/.local and ~/.npm-global,
# so they self-update like on the Mac. Nix provides the stable tooling.
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
    playwright-test
  ];

  # The T3 installer puts `t3` in ~/.local/bin.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
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
    };
  };

  programs.home-manager.enable = true;
}
