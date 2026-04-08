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

    t3code-nix = {
      url = "github:Sawrz/t3code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix

        # Overlay: expose third-party flake packages as if they were in nixpkgs
        {
          nixpkgs.overlays = [
            (final: prev: {
              claude-code = inputs.claude-code-nix.packages.${prev.system}.default;
              antigravity = inputs.antigravity-nix.packages.${prev.system}.default;
              codex = inputs.codex-cli-nix.packages.${prev.system}.default;
              t3code = inputs.t3code-nix.packages.${prev.system}.t3code;
              t3 = inputs.t3code-nix.packages.${prev.system}.t3;
            })
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.dwitt = import ./home.nix;
        }
      ];
    };
  };
}
