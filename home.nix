{ config, pkgs, ... }:
{
  home.username = "dwitt";
  home.homeDirectory = "/home/dwitt";
  home.stateVersion = "25.11";

  # Packages
  home.packages = with pkgs; [
    # GUI apps
    kdePackages.kate
    code-cursor
    ghostty
    zed-editor

    # CLI essentials (modern replacements - learn these alongside the originals)
    ripgrep
    fd
    bat
    eza
    jq
    yq
    tree
    unzip
    p7zip
    tldr
    nix-your-shell

    # File sync / remote work
    rsync
    rclone
    sshfs
    mosh

    # System monitoring
    btop
    nvtopPackages.full
    duf
    dust

    # Audio
    ffmpeg-full
    crosspipe
    easyeffects
    pavucontrol

    # Dev tools
    nodejs_22
    pnpm
    doppler

    # AI coding assistants (via overlay → third-party flakes for fresh updates)
    claude-code
    antigravity
    codex
    t3
    t3code
  ];

  # Cross-shell session variables (available in both fish and bash)
  home.sessionVariables = {
    EDITOR = "zed --wait";
  };

  # Cross-shell aliases - these work in both fish and bash
  home.shellAliases = {
    nrs = "nh os switch";
    nrt = "nh os test";
    nrb = "nh os boot";
    nfu = "nix flake update";
  };

  # Auto-start Ghostty on login
  home.file.".config/autostart/ghostty.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Ghostty
    Exec=ghostty
    X-GNOME-Autostart-enabled=true
    Hidden=false
    NoDisplay=false
  '';

  # Fish as interactive shell
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting  # disable the startup greeting

      # nix-your-shell: make nix-shell / nix develop use fish instead of bash
      nix-your-shell fish | source
    '';

    # Abbreviations - expand visibly when you press space
    # Use these as shortcuts for the modern CLI tools
    shellAbbrs = {
      # Modern tool shortcuts (abbreviated so you see what you're running)
      g  = "rg";      # grep-ish
      f  = "fd";      # find-ish
      c  = "bat";     # cat-ish
      l  = "eza";     # ls-ish
      la = "eza -la --git";
      lt = "eza --tree";

      # Git shortcuts
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";

      # Nix shortcuts (on top of the nrs/nrt/nrb aliases)
      nfs = "nix flake show";
      nfc = "nix flake check";
    };

    plugins = [
      { name = "fzf-fish";           src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "fish-you-should-use"; src = pkgs.fishPlugins.fish-you-should-use.src; }
      { name = "puffer";              src = pkgs.fishPlugins.puffer.src; }
      { name = "sponge";              src = pkgs.fishPlugins.sponge.src; }
    ];
  };

  # Bash stays available for scripts and for agents
  programs.bash = {
    enable = true;
  };

  # Starship prompt - shows git status, node version, nix shell, etc.
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    # Default config is already very nice. Override here if you want.
    # settings = { ... };
  };

  # fzf - fuzzy finder, Ctrl+R history search and more
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };

  # zoxide - smarter cd that learns your directories
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };

  # Direnv - for future per-project dev shells when you're ready
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };

  # Ghostty terminal with Quick Terminal (F12 drop-down)
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Fairyfloss";
      font-family = "Hack Nerd Font";
      font-size = 12;

      # Quick terminal (drop-down mode)
      quick-terminal-position = "top";
      quick-terminal-screen = "main";
      quick-terminal-autohide = false;
      gtk-single-instance = true;
      quick-terminal-size = "50%,100%";  # height, width

      keybind = [
        "global:f12=toggle_quick_terminal"
      ];
    };
  };

  # nh - nicer nixos-rebuild wrapper with periodic cleanup
  programs.nh = {
    enable = true;
    flake = "/home/dwitt/nixos-config";
    clean = {
      enable = true;
      extraArgs = "--keep-since 30d --keep 5";
    };
  };

  # Git with your rebase workflow
  programs.git = {
    enable = true;
    userName = "Dahlia Witt";
    userEmail = "dwitt@dranweb.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      rebase.updateRefs = true;
    };
  };

  programs.home-manager.enable = true;
}