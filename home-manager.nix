{ pi, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  extensions = import ./nix/pi-extensions.nix { inherit pkgs inputs; };
  ponytail = import ./nix/ponytail.nix {
    inherit pkgs;
    source = inputs.ponytail;
  };
  codexDir =
    if config.home.preferXdgDirectories then
      "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
    else
      ".codex";
  ponytailCachePath = "${codexDir}/plugins/cache/home-manager/ponytail/${ponytail.version}";
  ponytailSkills = [
    "ponytail"
    "ponytail-review"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
  ];
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
  home.packages = [ pkgs.nodejs ];
  home.file =
    lib.mapAttrs' (
      name: package: lib.nameValuePair ".pi/agent/extensions/${name}" { source = package; }
    ) (extensions // { ponytail = "${ponytail}/pi-extension"; })
    // lib.genAttrs (map (name: ".pi/agent/skills/${name}") ponytailSkills) (path: {
      source = "${ponytail}/skills/${baseNameOf path}";
    })
    // {
      # Codex 0.160 ignores symlinked version directories when selecting an
      # installed plugin. Keep the directory real and link its static children.
      ${ponytailCachePath}.recursive = true;
    };

  # HM's normal collision handling can back up and replace this catalog. Stop
  # first instead: the user must reconcile unrelated entries into their config.
  home.activation.checkPersonalCodexCatalog = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    catalog="$HOME/.agents/plugins/marketplace.json"
    if [[ -e "$catalog" || -L "$catalog" ]]; then
      target="$(readlink "$catalog" || true)"
      if [[ "$target" != ${builtins.storeDir}/*-home-manager-files/.agents/plugins/marketplace.json ]] ||
        ! ${lib.getExe pkgs.jaq} -e --slurpfile generated ${
          config.home.file.".agents/plugins/marketplace.json".source
        } '
          .name == $generated[0].name and
          (.plugins | type == "array") and
          all(.plugins[]; .name == "ponytail" or
            (. as $plugin | any($generated[0].plugins[]; . == $plugin)))
        ' "$catalog" >/dev/null; then
        echo "ai-setup: existing personal plugin catalog at $catalog; preserve it and reconcile its plugins/marketplaces before activating (see README)." >&2
        exit 1
      fi
    fi
  '';

  # Codex also rejects a symlinked manifest or metadata directory. Materialize
  # only this metadata, not the full plugin or any hook-trust state.
  home.activation.materializePonytailManifest = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    metadata="$HOME"/${lib.escapeShellArg ponytailCachePath}/.codex-plugin
    run rm -f "$metadata"
    run mkdir -p "$metadata"
    run install -m644 ${ponytail}/.codex-plugin/plugin.json "$metadata/plugin.json"
  '';

  programs.codex = {
    enable = true;
    package = lib.mkDefault pkgs.codex;
    mutableSettings = true;
    plugins = [ ponytail ];
    settings.plugins."ponytail@ponytail".enabled = lib.mkForce false;
  };
}
