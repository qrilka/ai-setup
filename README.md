# AI tools setup

A shared global Pi and Codex setup for Linux machines.

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

Rerunning `just install` is supported. It preserves credentials, unrelated settings,
and unrelated skills, but **replaces managed skills with current upstream content**.
Back up local edits first; the maintainer's `to-tickets` copy has additions not present
upstream. npm packages follow `latest`; Git skills and Ponytail follow upstream branches,
so machines installed at different times may receive different versions.

After installation, sign in separately on each machine (`pi` → `/login`, `codex login`).
In Codex, open `/hooks`, review and trust Ponytail's lifecycle hooks, then start a new
thread. Installation enables the plugin but **does not bypass hook trust**. Provider
credentials and optional extension dependencies (such as a browser for preview rendering)
are not provisioned here.

`just update` is tracked separately in ticket 02 and is not implemented yet.

## Verify

With Docker installed and its daemon running:

```sh
just test
```

This builds a clean Linux image with the prerequisites and runs the real installer
as a non-root user. No host home directory, credentials, or Docker socket is mounted.
It verifies CLI versions against npm, Pi's loaded extension registrations, both
agents' discovery of all selected skills, the enabled Ponytail plugin and its skills,
and a second install preserving seeded settings, dummy credentials, and a custom skill.
Agent discovery runs outside the setup checkout. No model calls or real credentials
are used; this checks host integration, not every extension feature or model behavior.
Docker may block Codex's nested bubblewrap sandbox and log a user-namespace warning;
this test does not execute Codex tools or relax Docker's isolation to suppress it.
