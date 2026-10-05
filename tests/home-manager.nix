{
  pkgs,
  pi,
  home-manager,
  module,
}:
let
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      module
      {
        home.username = "ai-setup-test";
        home.homeDirectory = "/home/ai-setup-test";
        home.stateVersion = "26.05";
        home.packages = [ pkgs.hello ];
        home.file."unrelated.txt".text = "user-owned declaration";
      }
    ];
  };
  cfg = home.config;
  protected =
    path:
    pkgs.lib.any (prefix: pkgs.lib.hasPrefix prefix path) [
      ".pi/"
      ".codex/"
      "${cfg.home.homeDirectory}/.pi/"
      "${cfg.home.homeDirectory}/.codex/"
    ];
in
assert cfg.programs.pi-coding-agent.enable;
assert cfg.programs.codex.enable;
assert cfg.programs.pi-coding-agent.package == pi.packages.x86_64-linux.default;
assert cfg.programs.codex.package == pkgs.codex;
assert builtins.elem pi.packages.x86_64-linux.default cfg.home.packages;
assert builtins.elem pkgs.codex cfg.home.packages;
assert builtins.elem pkgs.hello cfg.home.packages;
assert cfg.home.file."unrelated.txt".text == "user-owned declaration";
assert !(pkgs.lib.any protected (builtins.attrNames cfg.home.file));
assert cfg.programs.pi-coding-agent.configDir == "${cfg.home.homeDirectory}/.pi/agent";
assert !(cfg.home.sessionVariables ? PI_CODING_AGENT_DIR);
assert !(cfg.home.sessionVariables ? CODEX_HOME);
assert pkgs.lib.all (entry: entry.assertion) cfg.assertions;
pkgs.runCommand "ai-setup-home-manager-check" { } ''
  test -f ${home.activationPackage}/activate
  touch "$out"
''
