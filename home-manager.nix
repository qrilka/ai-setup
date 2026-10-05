{ pi, inputs }:
{ lib, pkgs, ... }:
let
  extensions = import ./nix/pi-extensions.nix { inherit pkgs inputs; };
in
{
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "ai-setup supports x86_64-linux only.";
    }
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = lib.mkDefault pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
  home.file = lib.mapAttrs' (
    name: package: lib.nameValuePair ".pi/agent/extensions/${name}" { source = package; }
  ) extensions;

  programs.codex = {
    enable = true;
    package = lib.mkDefault pkgs.codex;
  };
}
