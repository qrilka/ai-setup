# AI tools setup

A shared global Pi and Codex setup for Linux machines.

## Nix/Home Manager CLI base (in progress)

The flake currently provides **only Pi and Codex CLIs** on `x86_64-linux`.
Pi comes from its official stable flake; Codex comes from Nixpkgs. Extension,
plugin, and skill migration is still pending, so this does not yet replace the
full installer below.

Add this input to your existing Home Manager flake:

```nix
inputs.ai-setup.url = "github:qrilka/ai-setup";
```

Then include `inputs.ai-setup.homeManagerModules.default` in the `modules` list
of your existing `home-manager.lib.homeManagerConfiguration`. Keep your own
username, home directory, state version, and other modules. No `extraSpecialArgs`
or overlay is needed. Codex uses your Home Manager configuration's `pkgs.codex`;
Pi uses the official package pinned through the ai-setup input.

Use a recent Home Manager with `programs.pi-coding-agent.enable` and `package`,
and `programs.codex.enable` and `package`. The evaluation/build check is tested
with Home Manager revision `f53f3267f5d009dd8f99443505e609389d7ff267` (master,
2026-10-05), Nixpkgs unstable, and Nix 2.19.2 with `nix-command` and `flakes` enabled.
The module leaves agent settings and credentials unmanaged: in particular,
Pi continues using your existing `~/.pi/agent/models.json`, settings, keybindings,
authentication, and sessions. It does not change Pi's agent directory or declare
Codex settings. Do not separately declare those files through Home Manager unless
you intend to take ownership of them.

Versions follow your consumer lockfile, not npm's `latest`. Refresh the ai-setup
input deliberately, review the resulting lock changes, and activate through your
usual Home Manager workflow. For consumer-selected Nixpkgs versions, optionally
set `inputs.ai-setup.inputs.nixpkgs.follows = "nixpkgs"`; the consumer's Home Manager
must still be compatible.

To check this repository without activating your home:

```sh
nix flake check
```

This builds both CLIs and a test Home Manager generation, checks their selection
and that no agent-owned files or agent-directory overrides are generated, but
never executes the activation script or makes model calls.

## Install

Prerequisites: Node.js **22.19+**, npm/npx, Git, and [just](https://just.systems).
Use a writable npm global prefix with its `bin` directory on `PATH` (for example,
a user-managed Node installation). No `sudo` is needed by this repo. Install
`bubblewrap` with your OS package manager for Codex's Linux sandbox.

```sh
git clone https://github.com/qrilka/ai-setup.git
cd ai-setup
just install
```

The inventory lives in `justfile`:

- Latest Pi (`@earendil-works/pi-coding-agent`) and Codex (`@openai/codex`) CLIs.
- Pi packages: markdown preview, ask-user-question, web access, subagents, and Ponytail.
- 27 selected skills from `mattpocock/skills` and `show-me` from `humanlayer/skills`.
- The Ponytail Codex plugin and its six skills. Codex namespaces these as `ponytail:<skill>`.

Shared skills are installed once under `~/.agents/skills`, which both agents discover.
The setup does not manage `find-skills` or `solana-dev`.

`just install` installs the inventory in `justfile`. `just update` uses Pi's native
`pi update --all`, which updates Pi and every package configured in Pi (including any
extra packages), and updates the managed Codex CLI, selected skills, and Ponytail
marketplace. Updates preserve credentials, unrelated settings, and unrelated skills,
but **replace managed skills with current upstream content**. Back up local edits first;
the maintainer's `to-tickets` copy has additions not present upstream. npm packages
follow `latest`; Git skills and Ponytail follow upstream branches, so machines installed
at different times may receive different versions.

After installation, sign in separately on each machine (`pi` → `/login`, `codex login`).
In Codex, open `/hooks`, review and trust Ponytail's lifecycle hooks, then start a new
thread. Installation enables the plugin but **does not bypass hook trust**. Provider
credentials and optional extension dependencies (such as a browser for preview rendering)
are not provisioned here.

## Verify

With Docker installed and its daemon running:

```sh
just test
```

This builds a clean Linux image with the prerequisites and runs the real installer
as a non-root user. No host home directory, credentials, or Docker socket is mounted.
It verifies CLI versions against npm, Pi's loaded extension registrations, both
agents' discovery of all selected skills, the enabled Ponytail plugin and its skills,
and a repeated install plus `just update` preserving seeded settings, dummy credentials,
and a custom skill.
Agent discovery runs outside the setup checkout. No model calls or real credentials
are used; this checks host integration, not every extension feature or model behavior.
Docker may block Codex's nested bubblewrap sandbox and log a user-namespace warning;
this test does not execute Codex tools or relax Docker's isolation to suppress it.
