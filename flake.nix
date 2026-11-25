{
  description = "Dahlia's NixOS configuration";

  inputs = {
    # Track the unstable channel. Use "nixos-25.11" if you prefer the stable release.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    playwright = {
      url = "github:pietdevries94/playwright-web-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    endcordPackage = {
      lib,
      stdenvNoCC,
      fetchFromGitHub,
      makeWrapper,
      python313,
      aspellWithDicts,
      git,
      glib,
      gnome-keyring,
      kdePackages,
      libnotify,
      libsecret,
      mpv,
      pipewire,
      wl-clipboard,
      xclip,
      xdg-utils,
      yt-dlp,
      zenity,
    }:
    let
      python = python313;
      pythonEnv = python.withPackages (ps: [
        ps.av
        ps.emoji
        ps.filetype
        ps.keyring
        ps.numpy
        ps.orjson
        ps.pillow
        ps.protobuf
        ps.pycryptodome
        ps.pynacl
        ps.pyperclip
        ps.pysocks
        ps.pystray
        ps."python-socks"
        ps.qrcode
        ps.secretstorage
        ps.soundcard
        ps.soundfile
        ps.urllib3
        ps."websocket-client"
      ]);

      aspell = aspellWithDicts (dicts: [ dicts.en ]);
      runtimeInputs = [
        aspell
        git
        glib
        gnome-keyring
        kdePackages.kdialog
        libnotify
        libsecret
        mpv
        pipewire
        wl-clipboard
        xclip
        xdg-utils
        yt-dlp
        zenity
      ];
    in
    stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "endcord";
      version = "1.4.1";

      src = fetchFromGitHub {
        owner = "sparklost";
        repo = "endcord";
        rev = finalAttrs.version;
        hash = "sha256-1CFr9Y/5qZfkTIOFBuN7MlvJsnmOp9JK/ZJB3INWxpY=";
      };

      nativeBuildInputs = [ makeWrapper ];

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/bin" "$out/share/endcord"
        cp -r . "$out/share/endcord"

        makeWrapper ${pythonEnv}/bin/python "$out/bin/endcord" \
          --add-flags "$out/share/endcord/main.py" \
          --set PYTHONPATH "$out/share/endcord" \
          --prefix PATH : ${lib.makeBinPath runtimeInputs}

        runHook postInstall
      '';

      meta = with lib; {
        description = "Feature-rich Discord TUI client";
        homepage = "https://github.com/sparklost/endcord";
        license = licenses.gpl3Only;
        mainProgram = "endcord";
        platforms = platforms.linux;
      };
    });
  in {
    nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix

        # Overlay: expose third-party flake packages as if they were in nixpkgs
        {
          nixpkgs.overlays = [
            (final: prev:
              let
                playwright-packages =
                  final.callPackage "${inputs.playwright}/playwright-driver/driver.nix" { };
              in {
                claude-code = inputs.claude-code-nix.packages.${prev.system}.default;
                antigravity = inputs.antigravity-nix.packages.${prev.system}.default;
                codex = inputs.codex-cli-nix.packages.${prev.system}.default;
                endcord = prev.callPackage endcordPackage { };
                playwright-test = playwright-packages.playwright-test;
                playwright-driver = playwright-packages.playwright-core;
              })
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.dwitt = import ./home.nix;
          home-manager.users.agent = import ./agent-home.nix;
        }
      ];
    };
  };
}
