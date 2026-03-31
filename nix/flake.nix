{
  description = "Home NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix }: {
    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs-unstable; };
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/nas/configuration.nix
      ];
    };

    nixosConfigurations.iot = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs-unstable; };
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/iot/configuration.nix
      ];
    };
  };
}
