{ pkgs, source }:
let
  manifest = pkgs.lib.importJSON (source + "/.codex-plugin/plugin.json");
in
pkgs.runCommand "ponytail-${manifest.version}"
  {
    pname = "ponytail";
    inherit (manifest) version;
  }
  ''
    mkdir -p "$out"
    # A real HM version directory contains these top-level links. Keeping the
    # skills directory linked leaves its SKILL.md files regular, as Codex needs.
    shopt -s dotglob
    for path in ${source}/*; do
      # Codex rejects a symlinked root plugin.json even when it is an unrelated
      # Hermes descriptor. Use the complete .codex-plugin manifest instead.
      [[ "$path" == ${source}/plugin.json ]] && continue
      ln -s "$path" "$out/$(basename "$path")"
    done
  ''
