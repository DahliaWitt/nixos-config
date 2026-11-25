# Home Manager config for the unprivileged `agent` user (see remote.nix).
# The T3 server runs here as a systemd user service installed by `t3 up`.
{ pkgs, ... }:
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    claude-code
    codex
    gemini-cli

    git
    gh
    jq
    ripgrep
    fd
    just
    nodejs_22
    pnpm
    bubblewrap
    playwright-test
  ];

  # The T3 installer puts `t3` in ~/.local/bin.
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
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
