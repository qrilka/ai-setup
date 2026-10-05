# AI tools setup

A shared global Pi and Codex setup for Linux machines.

## Nix and Home Manager

This flake provides **Pi and Codex CLIs, four Pi extensions, Ponytail, and 28
selected shared skills** through a Home Manager module on `x86_64-linux`. Pi
comes from its official stable flake; Codex comes from Nixpkgs. Skills are
pinned and linked individually.

Add this input to your existing Home Manager flake:

```nix
inputs.ai-setup.url = "github:qrilka/ai-setup";
```

Then include `inputs.ai-setup.homeManagerModules.default` in the `modules` list
of your existing `home-manager.lib.homeManagerConfiguration`. Keep your own
username, home directory, state version, and other modules. No `extraSpecialArgs`
or overlay is needed. Codex uses your Home Manager configuration's `pkgs.codex`;
Pi uses the official package pinned through the ai-setup input.

Activate it with your usual Home Manager workflow, for example:

```sh
home-manager switch --flake .#alice@laptop
```

After activation, sign in separately with Pi's `/login` and `codex login`. Review
and trust Ponytail's hooks manually in Codex before starting a new thread.

This assumes Nix flakes and Home Manager are already configured on an
`x86_64-linux` host; it does not provision an operating system or install Nix.
Use a recent Home Manager with `programs.pi-coding-agent.enable` and `package`,
and `programs.codex.plugins` and `mutableSettings`. The checks use Home Manager
revision `f53f3267f5d009dd8f99443505e609389d7ff267` (master, 2026-10-05), Nixpkgs
unstable, and Nix 2.19.2 with `nix-command` and `flakes` enabled. Codex's
Nixpkgs package includes `bubblewrap` for its Linux sandbox.
Pi continues using your existing `~/.pi/agent/models.json`, settings, keybindings,
authentication, and sessions. The module does not change Pi's agent directory
or manage these mutable files. Do not separately declare them through Home
Manager unless you intend to take ownership of them.

Codex's `config.toml` remains writable: Home Manager merges declared plugin
settings into the existing configuration, retaining unrelated settings and
marketplaces. Credentials remain unmanaged. Do not also manage `config.toml`
as an immutable `home.file` or disable `programs.codex.mutableSettings`.

Versions follow your consumer lockfile. Refresh the ai-setup input deliberately
and review the lock changes before activating:

```sh
nix flake lock --update-input ai-setup
```

For consumer-selected Nixpkgs versions, optionally set
`inputs.ai-setup.inputs.nixpkgs.follows = "nixpkgs"`; the consumer's Home Manager
must still be compatible.

To check this repository without activating your home:

```sh
nix flake check
```

This builds both CLIs, all four extensions, Ponytail, the selected-skill bundle,
and a test Home Manager generation. It checks individual links and Pi resource
loading, then activates twice inside a sandboxed disposable home. Pi and Codex
must discover all 28 shared skills, while Codex also sees the six namespaced
Ponytail skills and three still-untrusted hooks. Seeded settings, dummy credentials,
unrelated skills/extensions, a custom Pi provider/model, and a conflicting personal
catalog exercise preservation. Pi discovers the custom model without a model
request. The check never activates your real home or executes hooks.

### Pi extensions and existing installations

Pinned sources and their upstream dependency locks provide `pi-markdown-preview`,
`@juicesharp/rpiv-ask-user-question`, `pi-web-access`, and `pi-subagents`. Each is
linked individually under `~/.pi/agent/extensions/`; the containing directory and
`settings.json` remain user-owned. Builds install npm dependencies offline from
integrity-checked Nix inputs, exclude Pi host peers, and do not run npm lifecycle
scripts. Activation does not fetch from npm or Git. The questionnaire copies its
three locked TypeScript workspaces; other monorepo packages are not installed.

**Before first activation on an existing installation**, back up
`~/.pi/agent/settings.json` and edit only its `packages` array. Remove the four old
managed declarations below, including version-qualified variants. Entries may
be strings or objects with a `source` field; remove the whole matching entry:

```text
npm:pi-markdown-preview
npm:@juicesharp/rpiv-ask-user-question
npm:pi-web-access
npm:pi-subagents
```

Also remove the old managed `git:github.com/DietrichGebert/ponytail` entry
(including revision-qualified variants) now that its extension and skills come
from Nix. Check project `.pi/settings.json` for declarations of these same
packages if you previously installed them locally; remove only those matching
entries too. Keep every unrelated entry, all other settings, and `models.json`.
This avoids loading the old npm copy alongside its Nix link. Nix never rewrites
those settings or deletes old caches. If a destination
such as `~/.pi/agent/extensions/pi-web-access` already exists, move that child
aside after inspecting/backing it up; do not replace the containing directory.

Pandoc, a browser/Chromium, and LaTeX remain optional markdown-preview feature
dependencies; install them separately only for the rendering modes you use.
Web-provider credentials and optional web/video tools are also not provisioned.
The check covers discovery/registration, not model calls or every feature.

To update these extensions, change their source revisions in `flake.nix`, run
`nix flake lock`, review the source/lock changes, and run `nix flake check` before
committing. Consumer deployments update their ai-setup input as described above.

### Ponytail and Codex migration

One pinned Ponytail source supplies the Pi extension, six individual Pi skill
links, and the Codex plugin's manifest, skills, hooks, scripts, and assets. Codex
skills retain `ponytail:<skill>` names; no unnamespaced shared copies are added.
Node is included in the Home Manager profile so hooks can resolve it without
shell startup files. Start Codex from that profile's PATH.

Home Manager enables `ponytail@home-manager` and explicitly disables the old
`ponytail@ponytail` identity without removing unrelated plugins or marketplaces.
Old caches are not deleted. Inspect and move aside only conflicting managed Pi
extension/skill children, never their containing directories.

**An existing personal `~/.agents/plugins/marketplace.json` stops activation**,
even when Home Manager backups are enabled. Preserve that catalog and back up
Codex's config before reconciling it. Keep unrelated catalog entries in a separate
marketplace root containing `.agents/plugins/marketplace.json`, adjust relative
plugin source paths as needed, and register that root in your Home Manager config,
for example:

```nix
programs.codex.marketplaces.personal = "/home/you/preserved-marketplace";
```

Retain the appropriate enabled plugin identities/settings for that marketplace,
or declare its plugins through `programs.codex.plugins`. Only after reconciliation,
move the original catalog out of the managed destination; do not remove the
`.agents/plugins` directory. The next activation writes Home Manager's catalog.
An existing Home Manager-owned catalog can be updated normally only when its
marketplace identity and all unrelated plugin entries are retained. If entries
would be changed or lost, the same preservation/reconciliation guard applies.

Codex 0.160 ignores symlinked plugin-version directories and rejects symlinked
manifests. The module keeps Ponytail's version directory real, links its static
children, and materializes only `.codex-plugin/plugin.json` from the pinned source
after linking. Activation does not run Git, npm, or plugin-install commands.

**Hook trust stays manual.** In Codex, open `/hooks`, inspect Ponytail's lifecycle
hooks, and trust them yourself before starting a new thread. Neither Nix nor
activation writes hook-trust state or exposes the hooks as managed/trusted hooks.

### Shared skills and existing installations

A pinned Matt Pocock source supplies all 27 selected skills, including
`to-tickets`; a pinned HumanLayer source supplies `show-me`. The upstream `pr`
skill carries its HumanLayer attribution. Pi and Codex discover all 28 from
`~/.agents/skills`; the flake adds no local skill copies or overlays.

Home Manager links each skill as its own child entry; it does not link, replace,
recursively synchronize, or delete `~/.agents/skills`. Existing unrelated skills
remain user-owned. Before first activation, inspect and move aside only colliding
copies of the 28 managed skills from previous installations; leave every other
skill and the containing directory in place. Activation itself uses only the
locked store sources and does not fetch or mutate GitHub content.
