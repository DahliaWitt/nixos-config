# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  windowsVmName = "windows-11-raw";
  windowsDisk = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RANX0H415147Y";
  hostBootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NC0MC22234Z";
  windowsVmXml = pkgs.writeText "${windowsVmName}.xml" ''
    <domain type='kvm'>
      <name>${windowsVmName}</name>
      <uuid>2677d02a-8314-4104-923f-c8436bc5c287</uuid>
      <memory unit='MiB'>8192</memory>
      <currentMemory unit='MiB'>8192</currentMemory>
      <vcpu placement='static'>8</vcpu>

      <os firmware='efi'>
        <type arch='x86_64' machine='q35'>hvm</type>
        <firmware>
          <feature enabled='no' name='secure-boot'/>
        </firmware>
        <boot dev='hd'/>
      </os>

      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
        </hyperv>
        <vmport state='off'/>
      </features>

      <cpu mode='host-passthrough' check='none'/>
      <clock offset='localtime'/>

      <devices>
        <disk type='block' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='native'/>
          <source dev='${windowsDisk}'/>
          <target dev='sda' bus='sata'/>
        </disk>

        <disk type='block' device='disk'>
          <driver name='qemu' type='raw' cache='none'/>
          <source dev='${hostBootDisk}'/>
          <target dev='sdb' bus='usb'/>
          <readonly/>
        </disk>

        <controller type='usb' model='qemu-xhci'/>
        <controller type='sata' index='0'/>

        <interface type='user'>
          <model type='e1000e'/>
        </interface>

        <input type='tablet' bus='usb'/>
        <input type='keyboard' bus='usb'/>

        <graphics type='spice' autoport='yes'>
          <listen type='address'/>
        </graphics>
        <video>
          <model type='qxl'/>
        </video>
        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>

        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>

        <memballoon model='none'/>
      </devices>
    </domain>
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.extraEntries."windows-11.conf" = ''
    title Windows 11
    efi /EFI/Microsoft/Boot/bootmgfw.efi
    sort-key z_windows
  '';
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "nvidia.NVreg_TemporaryFilePath=/var/tmp" ];

  networking.hostName = "nixos-btw";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Compressed in-memory swap helps smooth over memory spikes without disk swap.
  zramSwap.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.dwitt = {
    isNormalUser = true;
    description = "Dahlia Witt";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" ];
    shell = pkgs.fish;
  };

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and the new nix command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optimize the nix store by hard-linking duplicate files
  nix.settings.auto-optimise-store = true;

  # NEW: Enable fish at system level (for completions and as a valid login shell)
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;

  programs.nix-ld.enable = true;

  programs.virt-manager.enable = true;

  # System-level packages (minimal - most user stuff lives in home.nix now)
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    google-chrome
    virt-viewer
  ];

  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
    onShutdown = "shutdown";

    qemu = {
      swtpm.enable = true;
      runAsRoot = true;
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  environment.etc."libvirt/${windowsVmName}.xml".source = windowsVmXml;

  # Keep the raw Windows system disk out of desktop automount flows. The VM
  # uses the whole drive, so host mounting its partitions during a VM run is unsafe.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_SERIAL}=="Samsung_SSD_850_EVO_500GB_S2RANX0H415147Y", ENV{UDISKS_IGNORE}="1"
  '';

  systemd.services.define-windows-11-raw-vm = {
    description = "Define the Windows 11 raw-disk libvirt domain";
    wantedBy = [ "multi-user.target" ];
    after = [ "libvirtd.service" ];
    wants = [ "libvirtd.service" ];
    path = [ pkgs.libvirt ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -e ${windowsDisk} ]; then
        echo "Windows disk not present: ${windowsDisk}" >&2
        exit 1
      fi

      if [ ! -e ${hostBootDisk} ]; then
        echo "Host boot disk not present: ${hostBootDisk}" >&2
        exit 1
      fi

      if ! virsh --connect qemu:///system define ${windowsVmXml}; then
        echo "Failed to define ${windowsVmName}; leaving system activation successful." >&2
        exit 0
      fi
    '';
  };

  services.dbus.packages = [ pkgs.logiops ];

  environment.etc."logid.cfg".text = ''
    devices: (
      {
        name: "Wireless Mouse MX Master 3";

        buttons: (
          {
            cid: 0xc3;
            action = {
              type: "Gestures";
              gestures: (
                {
                  direction: "Left";
                  mode: "OnRelease";
                  action = {
                    type: "Keypress";
                    keys: ["KEY_LEFTMETA", "KEY_LEFTCTRL", "KEY_LEFT"];
                  };
                },
                {
                  direction: "Up";
                  mode: "OnRelease";
                  action = {
                    type: "Keypress";
                    keys: ["KEY_LEFTMETA", "KEY_W"];
                  };
                },
                {
                  direction: "Down";
                  mode: "OnRelease";
                  action = {
                    type: "Keypress";
                    keys: ["KEY_LEFTMETA", "KEY_W"];
                  };
                },
                {
                  direction: "Right";
                  mode: "OnRelease";
                  action = {
                    type: "Keypress";
                    keys: ["KEY_LEFTMETA", "KEY_LEFTCTRL", "KEY_RIGHT"];
                  };
                },
                {
                  direction: "None";
                  mode: "NoPress";
                }
              );
            };
          }
        );
      }
    );
  '';

  systemd.services.logid = {
    description = "Logitech Configuration Daemon";
    wantedBy = [ "graphical.target" ];
    after = [ "multi-user.target" ];
    wants = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.logiops}/bin/logid";
      Restart = "on-failure";
      User = "root";
    };
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # NEW: Firmware updates
  services.fwupd.enable = true;
  services.hardware.openrgb.enable = true;

  # Install Hack Nerd Font system-wide so it's available to all apps
  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];

  # OpenGL support.
  hardware.graphics.enable = true;

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # Resume corruption on Plasma/Chromium is often caused by NVIDIA not
    # restoring display memory cleanly across suspend.
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.11";
}
