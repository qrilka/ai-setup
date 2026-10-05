{ pi }:
{ lib, pkgs, ... }:
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
  programs.codex = {
    enable = true;
    package = lib.mkDefault pkgs.codex;
  };
}
