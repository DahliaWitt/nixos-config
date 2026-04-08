{ config, lib, pkgs, ... }:
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
    gh
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
    nil
    doppler
    bubblewrap

    # AI coding assistants (via overlay → third-party flakes for fresh updates)
    claude-code
    antigravity
    codex
    gemini-cli
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
    # Start the single-instance app without creating an initial normal window.
    Exec=ghostty --gtk-single-instance=true --initial-window=false
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
      # KWin doesn't reliably expose edge-resize for the layer-shell quick
      # terminal, so keep a predictable config-driven height instead.
      quick-terminal-size = "40%,100%";  # height, width

      keybind = [
        "global:f12=toggle_quick_terminal"
      ];
    };
  };

  # Plasma's Sliding Popups effect animates the Ghostty quick terminal on
  # Wayland. On this setup that path is visually glitchy, so prefer instant and
  # reliable show/hide over compositor animation.
  home.activation.disableKWinSlidingPopups =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}"
      /run/current-system/sw/bin/kwriteconfig6 \
        --file "$config_dir/kwinrc" \
        --group Plugins \
        --key slidingpopupsEnabled \
        --type bool \
        false \
        --notify
    '';

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
    settings = {
      user.name = "Dahlia Witt";
      user.email = "dwitt@dranweb.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      rebase.updateRefs = true;
    };
  };

  # tmux with Home Manager-managed plugins instead of TPM
  programs.tmux = {
    enable = true;
    sensibleOnTop = true;
    prefix = "C-a";
    mouse = true;
    focusEvents = true;
    escapeTime = 50;
    historyLimit = 30000;
    terminal = "tmux-256color";

    extraConfig = ''
      # Reload the generated Home Manager config.
      bind r source-file ~/.config/tmux/tmux.conf

      # Forward copies to the terminal clipboard when supported.
      set -g set-clipboard on

      # split panes using | and -
      bind | split-window -h
      bind - split-window -v

      # switch windows using alt-arrow without prefix
      bind -n M-Left previous-window
      bind -n M-Right next-window

      # switch panes using Ctrl-arrow without prefix
      bind -n C-Left select-pane -L
      bind -n C-Right select-pane -R
      bind -n C-Up select-pane -U
      bind -n C-Down select-pane -D

      # Set ability to capture on start and restore on exit window data when
      # running an application.
      setw -g alternate-screen on

      # don't rename windows automatically
      set-option -g allow-rename off

      ######################
      ### DESIGN CHANGES ###
      ######################

      ## Status bar design

      # loud or quiet?
      set-option -g visual-activity off
      set-option -g visual-bell off
      set-option -g visual-silence off
      set-window-option -g monitor-activity off
      set-option -g bell-action none

      # The modes
      setw -g clock-mode-colour colour135
      setw -g mode-style "fg=colour196 bg=colour238 bold"

      # The panes
      set -g pane-border-style "fg=colour238 bg=colour235"
      set -g pane-active-border-style "fg=colour51 bg=colour236"

      # The statusbar
      set -g status-style "fg=colour137 bg=colour234 dim"
      set -g status-interval 1
      set -g status-justify left
      set -g status-left ""
      set -g status-left-length 20
      set -g status-position bottom
      set -g status-right "#[fg=colour233 bg=colour241,bold] %d/%m #[fg=colour233 bg=colour245,bold] %H:%M:%S "
      set -g status-right-length 50

      # window status
      setw -g window-status-current-style "fg=colour81 bg=colour238 bold"
      setw -g window-status-current-format " #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F "

      setw -g window-status-style "fg=colour138 bg=colour235 none"
      setw -g window-status-format " #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F "

      setw -g window-status-bell-style "fg=colour255 bg=colour1 bold"

      # The messages
      set -g message-style "fg=colour232 bg=colour166 bold"
    '';

    plugins = with pkgs.tmuxPlugins; [
      yank
      better-mouse-mode
      {
        plugin = tmux-thumbs;
        extraConfig = ''
          set -g @thumbs-osc52 on
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-save-shell-history 'on'
        '';
      }
    ];
  };

  programs.home-manager.enable = true;
}
