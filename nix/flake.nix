{
  description = "Home NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, nixos-hardware }:
  let
    constants = {
      network = {
        lan        = "192.168.12.0/24";
        k3sPodCidr = "10.42.0.0/16";
      };
      hosts = {
        nasIp = "192.168.12.8";
      };
    };
  in {
    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs-unstable constants; };
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/nas/configuration.nix
      ];
    };

    nixosConfigurations.iot = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs-unstable constants; };
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/iot/configuration.nix
      ];
    };

    nixosConfigurations.bastion = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit nixpkgs-unstable constants; };
      modules = [
        sops-nix.nixosModules.sops
        nixos-hardware.nixosModules.raspberry-pi-4
        ./hosts/bastion/configuration.nix
      ];
    };
  };
}
