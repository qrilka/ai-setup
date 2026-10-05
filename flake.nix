{
  description = "Shared Pi and Codex setup for Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pi.url = "github:earendil-works/pi/stable";
    pi.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      pi,
      home-manager,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeManagerModules.default = import ./home-manager.nix { inherit pi; };
      checks.${system} = {
        pi = pi.packages.${system}.default;
        codex = pkgs.codex;
        home-manager = import ./tests/home-manager.nix {
          inherit pkgs pi home-manager;
          module = self.homeManagerModules.default;
        };
      };
    };
}
