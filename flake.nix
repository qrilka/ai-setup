{
  description = "Shared Pi and Codex setup for Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pi.url = "github:earendil-works/pi/stable";
    pi.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    markdown-preview = {
      url = "github:omaclaren/pi-markdown-preview/b646f35e1ae906709ffce0203387ca24ba19ec0f";
      flake = false;
    };
    rpiv = {
      url = "github:juicesharp/rpiv-mono/68d9a0014b70006d7b04b57933752338a2716db7";
      flake = false;
    };
    web-access = {
      url = "github:nicobailon/pi-web-access/d9624588de4a92af1e73be731a462c9bdcfeb96d";
      flake = false;
    };
    subagents = {
      url = "github:nicobailon/pi-subagents/ba008223698e78ff71d75ed83076d858d14d9eee";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      pi,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      extensions = import ./nix/pi-extensions.nix { inherit pkgs inputs; };
    in
    {
      homeManagerModules.default = import ./home-manager.nix { inherit pi inputs; };
      packages.${system} = extensions;
      checks.${system} = extensions // {
        pi = pi.packages.${system}.default;
        codex = pkgs.codex;
        home-manager = import ./tests/home-manager.nix {
          inherit pkgs pi home-manager;
          module = self.homeManagerModules.default;
        };
      };
    };
}
