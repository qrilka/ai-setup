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
        home.homeDirectory = "/build/ai-setup-home";
        home.activationGenerateGcRoot = false;
        home.stateVersion = "26.05";
        home.packages = [ pkgs.hello ];
        home.file."unrelated.txt".text = "user-owned declaration";
        programs.codex.settings.plugins."unrelated@user".enabled = true;
      }
    ];
  };
  previousCatalog = pkgs.writeTextFile {
    name = "home-manager-files";
    destination = "/.agents/plugins/marketplace.json";
    text = builtins.toJSON {
      name = "home-manager";
      plugins = [
        {
          name = "personal-only";
          source = {
            source = "local";
            path = "personal-plugin";
          };
        }
      ];
    };
  };
  cfg = home.config;
  extensionNames = [
    "pi-markdown-preview"
    "rpiv-ask-user-question"
    "pi-web-access"
    "pi-subagents"
  ];
  extensionPaths = map (name: ".pi/agent/extensions/${name}") (extensionNames ++ [ "ponytail" ]);
  ponytailSkills = [
    "ponytail"
    "ponytail-review"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
  ];
  skillPaths = map (name: ".pi/agent/skills/${name}") ponytailSkills;
  pluginPaths = pkgs.lib.filter (pkgs.lib.hasPrefix ".codex/plugins/cache/home-manager/ponytail/") (
    builtins.attrNames cfg.home.file
  );
  protected =
    path:
    !(builtins.elem path (extensionPaths ++ skillPaths ++ pluginPaths))
    && pkgs.lib.any (prefix: pkgs.lib.hasPrefix prefix path) [
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
assert builtins.elem pkgs.nodejs cfg.home.packages;
assert cfg.programs.codex.mutableSettings;
assert cfg.programs.codex.settings.plugins."ponytail@ponytail".enabled == false;
assert cfg.programs.codex.settings.plugins."unrelated@user".enabled;
assert builtins.length cfg.programs.codex.plugins == 1;
assert (builtins.head cfg.programs.codex.plugins).pname == "ponytail";
assert builtins.length pluginPaths == 1;
assert !cfg.home.file.".agents/plugins/marketplace.json".force;
assert cfg.programs.codex.hooks == { };
assert pkgs.lib.all (
  path: builtins.hasAttr path cfg.home.file && !cfg.home.file.${path}.recursive
) skillPaths;
assert cfg.home.file."unrelated.txt".text == "user-owned declaration";
assert pkgs.lib.all (path: builtins.hasAttr path cfg.home.file) extensionPaths;
assert pkgs.lib.all (path: !cfg.home.file.${path}.recursive) extensionPaths;
assert !(pkgs.lib.any protected (builtins.attrNames cfg.home.file));
assert cfg.programs.pi-coding-agent.configDir == "${cfg.home.homeDirectory}/.pi/agent";
assert !(cfg.home.sessionVariables ? PI_CODING_AGENT_DIR);
assert !(cfg.home.sessionVariables ? CODEX_HOME);
assert pkgs.lib.all (entry: entry.assertion) cfg.assertions;
pkgs.runCommand "ai-setup-home-manager-check"
  {
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.nix
      pkgs.jaq
    ];
  }
  ''
    test -f ${home.activationPackage}/activate
    node --check ${./pi-extensions.mjs}
    node ${./pi-extensions.mjs} ${cfg.programs.pi-coding-agent.package} ${home.activationPackage}/home-files
    export HOME=/build/ai-setup-home USER=ai-setup-test
    export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state"
    export XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
    export NIX_REMOTE=local NIX_STATE_DIR="$TMPDIR/nix-state" NIX_LOG_DIR="$TMPDIR/nix-log"
    mkdir -p "$HOME" "$XDG_STATE_HOME/nix/profiles"
    nix-store --load-db < ${pkgs.closureInfo { rootPaths = [ home.activationPackage ]; }}/registration
    node --check ${./ponytail.mjs}
    node ${./ponytail.mjs} ${home.activationPackage} ${cfg.programs.pi-coding-agent.package} ${previousCatalog}
    touch "$out"
  ''
