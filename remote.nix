# Remote access and agent sandbox.
#
# - Tailscale + OpenSSH, reachable only over the tailnet.
# - dwitt: admin, passwordless sudo so rebuilds can run over SSH.
# - agent: unprivileged user that runs T3 Code, coding agents and CI. No sudo,
#   no access to /home/dwitt, rootless podman for containers.
{ pkgs, ... }:
let
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
    description = "T3 Code, coding agents and CI";
    # Start user services (the T3 server) at boot, with nobody logged in.
    linger = true;
    # SSH in as agent so `t3 up` gets a real systemd user session.
    openssh.authorizedKeys.keys = [ macbookKey ];
  };

  # Rootless containers for agents and CI, with a docker-compatible CLI.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # A remote host that suspends is unreachable. Plasma's idle suspend becomes a no-op.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
