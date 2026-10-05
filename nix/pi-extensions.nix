{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  hostPeer = name: lib.hasPrefix "@earendil-works/pi-" name || name == "typebox";
  cleanManifest =
    manifest:
    (builtins.removeAttrs manifest [ "devDependencies" ])
    // lib.optionalAttrs (manifest ? peerDependencies) {
      peerDependencies = lib.filterAttrs (name: _: !(hostPeer name)) manifest.peerDependencies;
    };
  npmExtension =
    src:
    let
      package = lib.importJSON (src + "/package.json");
      lock = lib.importJSON (src + "/package-lock.json");
      # Host Pi peers (including integrity-less wildcard lock entries) are never
      # fetched. Drop dev-only entries too; legacy-peer-deps keeps npm offline
      # without auto-installing another Pi runtime. Runtime integrity is upstream's.
      packageLock = lock // {
        packages = lib.mapAttrs (_: cleanManifest) (
          lib.filterAttrs (
            path: entry:
            !(entry.dev or false)
            && !(lib.any (name: lib.hasSuffix "node_modules/${name}" path) [
              "@earendil-works/pi-ai"
              "@earendil-works/pi-agent-core"
              "@earendil-works/pi-coding-agent"
              "@earendil-works/pi-tui"
              "typebox"
            ])
          ) lock.packages
        );
      };
    in
    pkgs.buildNpmPackage {
      pname = package.name;
      inherit (package) version;
      inherit src;
      npmDeps = pkgs.importNpmLock {
        package = cleanManifest package;
        inherit packageLock;
      };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      npmFlags = [
        "--legacy-peer-deps"
        "--ignore-scripts"
      ];
      dontNpmBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -R . "$out/"
        runHook postInstall
      '';
    };
  rpivSource = inputs.rpiv;
  rpivLock = lib.importJSON (rpivSource + "/package-lock.json");
  rpivManifest = name: lib.importJSON (rpivSource + "/packages/${name}/package.json");
  rpivNames = [
    "rpiv-ask-user-question"
    "rpiv-config"
    "rpiv-i18n"
  ];
  # These three locked workspaces have no external runtime dependencies. Copy
  # only them, not the monorepo's other extensions/site or development tools.
  # Fail closed if upstream introduces a dependency needing npm packaging.
  rpiv =
    assert lib.all (
      name:
      let
        package = rpivManifest name;
      in
      package.version == rpivLock.packages."packages/${name}".version
      && rpivLock.packages."node_modules/@juicesharp/${name}".resolved == "packages/${name}"
      &&
        builtins.attrNames (package.dependencies or { })
        == (if name == "rpiv-config" then [ ] else [ "@juicesharp/rpiv-config" ])
    ) rpivNames;
    pkgs.runCommand "rpiv-ask-user-question-${(rpivManifest "rpiv-ask-user-question").version}" { } ''
      mkdir -p "$out/node_modules/@juicesharp"
      cp -R ${rpivSource}/packages/rpiv-ask-user-question/. "$out/"
      cp -R ${rpivSource}/packages/rpiv-config "$out/node_modules/@juicesharp/"
      cp -R ${rpivSource}/packages/rpiv-i18n "$out/node_modules/@juicesharp/"
      cp ${rpivSource}/package-lock.json "$out/package-lock.json"
    '';
in
{
  pi-markdown-preview = npmExtension inputs.markdown-preview;
  rpiv-ask-user-question = rpiv;
  pi-web-access = npmExtension inputs.web-access;
  pi-subagents = npmExtension inputs.subagents;
}
