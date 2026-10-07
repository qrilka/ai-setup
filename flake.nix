{
  description = "Shared Pi and Codex setup for Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    matt-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };
    pi.url = "github:earendil-works/pi/stable";
    pi.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    markdown-preview = {
      url = "github:omaclaren/pi-markdown-preview";
      flake = false;
    };
    rpiv = {
      url = "github:juicesharp/rpiv-mono";
      flake = false;
    };
    web-access = {
      url = "github:nicobailon/pi-web-access";
      flake = false;
    };
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };
    subagents = {
      url = "github:nicobailon/pi-subagents";
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
      ponytail = import ./nix/ponytail.nix {
        inherit pkgs;
        source = inputs.ponytail;
      };
      sharedSkills = import ./nix/shared-skills.nix { inherit pkgs inputs; };
    in
    {
      homeManagerModules.default = import ./home-manager.nix { inherit pi inputs; };
      packages.${system} = extensions // {
        inherit ponytail;
        shared-skills = sharedSkills.bundle;
      };
      checks.${system} = extensions // {
        inherit ponytail;
        shared-skills =
          assert sharedSkills.selection."to-tickets".source == "matt";
          sharedSkills.bundle;
        pi = pi.packages.${system}.default;
        codex = pkgs.codex;
        home-manager = import ./tests/home-manager.nix {
          inherit pkgs pi home-manager;
          module = self.homeManagerModules.default;
        };
      };
    };
}
