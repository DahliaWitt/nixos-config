# Remote access and agent sandbox.
#
# - Tailscale + OpenSSH, reachable only over the tailnet.
# - dwitt: admin, passwordless sudo so rebuilds can run over SSH.
# - agent: unprivileged user that runs T3 Code, coding agents and CI. No sudo,
#   no access to /home/dwitt, rootless podman for containers.
# - Idle sleep with wake-on-LAN, so the box is off when nothing is running.
{ pkgs, ... }:
let
  # Exits 0 (busy) if processes owned by `agent` used more than 3% of one CPU
  # over a 10 second sample.
  agentCpuBusy = pkgs.writeShellScript "agent-cpu-busy" ''
    PATH=${pkgs.coreutils}/bin
    uid=$(id -u agent) || exit 1
    ticks() {
      local total=0 f line
      for f in /proc/[0-9]*; do
        [ "$(stat -c %u "$f" 2>/dev/null)" = "$uid" ] || continue
        line=$(< "$f/stat") 2>/dev/null || continue
        # Drop "pid (comm) " so a comm with spaces can't shift the fields.
        read -r -a s <<< "''${line##*) }"
        # utime and stime are fields 14 and 15 of the full line.
        total=$(( total + s[11] + s[12] ))
      done
      echo "$total"
    }
    a=$(ticks); sleep 10; b=$(ticks)
    # USER_HZ is 100, so 3% of one CPU over 10 s is 30 ticks.
    [ $(( b - a )) -gt 30 ]
  '';
  # Exits 0 (busy) while dwitt has a graphical session that swayidle has not
  # marked idle.
  desktopBusy = pkgs.writeShellScript "desktop-busy" ''
    PATH=${pkgs.coreutils}/bin:${pkgs.systemd}/bin
    uid=$(id -u dwitt) || exit 1
    [ -n "$(loginctl show-user dwitt -p Display --value 2>/dev/null)" ] || exit 1
    [ ! -e "/run/user/$uid/desktop-idle" ]
  '';
  macbookKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+LD+MInHfSHRsj6Wic41FXsx0jFAf1fhPNBP1kmPNg macbook->nixos-btw";
in
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Everything (SSH, T3 on 3773) is open over the tailnet and closed on the LAN.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "dwitt" "agent" ];
    };
  };

  users.users.dwitt.openssh.authorizedKeys.keys = [ macbookKey ];

  security.sudo.extraRules = [
    {
      users = [ "dwitt" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  users.users.agent = {
    isNormalUser = true;
    # Pinned: the memory protection below names user-1001.slice and user@1001.
    uid = 1001;
    description = "T3 Code, coding agents and CI";
    # Start user services (the T3 server) at boot, with nobody logged in.
    linger = true;
    # SSH in as agent so `t3 up` gets a real systemd user session.
    openssh.authorizedKeys.keys = [ macbookKey ];
  };

  # What `t3 service protect` sets up, declared here instead (user side in
  # agent-home.nix). Memory protection reaches the T3 server only if every
  # ancestor cgroup grants it, and the remote-access daemons outlive agents
  # under memory pressure so the box stays reachable.
  systemd.slices.user.sliceConfig.MemoryLow = "2G";
  systemd.slices."user-1001" = {
    overrideStrategy = "asDropin";
    sliceConfig.MemoryLow = "2G";
  };
  systemd.services."user@1001" = {
    overrideStrategy = "asDropin";
    # Don't set a minimal PATH on the user manager; its services get theirs
    # from environment.d (agent-home.nix).
    enableDefaultPath = false;
    serviceConfig = {
      MemoryLow = "2G";
      OOMScoreAdjust = -900;
    };
  };
  systemd.slices.system.sliceConfig.MemoryLow = "512M";
  systemd.services.sshd.serviceConfig = {
    MemoryLow = "256M";
    OOMScoreAdjust = -900;
  };
  systemd.services.tailscaled.serviceConfig = {
    MemoryLow = "256M";
    OOMScoreAdjust = -900;
  };

  # Follow main on GitHub, which .github/workflows/update.yml bumps daily at
  # 04:00. A failed build leaves the running generation in place; no reboots.
  system.autoUpgrade = {
    enable = true;
    flake = "github:DahliaWitt/nixos-config#nixos-btw";
    dates = "05:00";
    randomizedDelaySec = "15min";
    operation = "switch";
    allowReboot = false;
  };

  # Libraries for browsers that Playwright downloads per project (each repo
  # pins its own revision, which rarely matches the one in nixpkgs).
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  # Playwright's `channel: "chrome"` looks for Google Chrome at the FHS path.
  systemd.tmpfiles.rules = [
    "L+ /opt/google/chrome/chrome - - - - ${pkgs.google-chrome}/bin/google-chrome-stable"
  ];

  # Rootless containers for agents and CI, with a docker-compatible CLI.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # Idle sleep that respects background work. Plasma's own idle suspend only
  # watches keyboard and mouse, so it is turned off in home.nix and this
  # decides instead. It suspends after 20 minutes with none of the following.
  services.autosuspend = {
    # Off until Wake-on-LAN can reach the desktop: whiterose (192.168.2.x)
    # has no route to the Kabelsalat Wi-Fi (192.168.1.x), so a sleeping box
    # can't be woken remotely yet.
    enable = false;
    settings = {
      interval = 60;
      idle_time = 1200;
    };
    checks = {
      # Someone (or an agent on the Mac) is connected over SSH.
      RemoteSSH = {
        class = "ActiveConnection";
        ports = "22";
      };
      # Someone is using the desktop itself. Plasma never sets logind's idle
      # hint, so swayidle (home.nix) marks 15 min without input instead.
      LocalDesktop = {
        class = "ExternalCommand";
        command = "${desktopBusy}";
      };
      # Builds, tests, nix-daemon work.
      Load = {
        threshold = "1.5";
      };
      # Agents mid-turn: anything running as `agent` (T3 and its providers)
      # used over 3% of a CPU in the last 10 seconds. Idle T3 sits near 0.
      AgentCpu = {
        class = "ExternalCommand";
        command = "${agentCpuBusy}";
      };
    };
  };

  # Wake on LAN, wired and Wi-Fi (the Intel card supports WoWLAN magic
  # packets). The packet comes from whiterose, which is always on and on the
  # same LAN; see ~/.local/bin/wake-desktop on the Mac.
  networking.networkmanager.settings.connection = {
    "ethernet.wake-on-lan" = "magic";
    "wifi.wake-on-wlan" = "magic";
  };
}
