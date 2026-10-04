pi_cli_package := "@earendil-works/pi-coding-agent"
codex_cli_package := "@openai/codex"
pi_packages := "npm:pi-markdown-preview npm:@juicesharp/rpiv-ask-user-question npm:pi-web-access npm:pi-subagents git:github.com/DietrichGebert/ponytail"
mattpocock_skills := "ask-matt codebase-design code-review diagnosing-bugs domain-modeling grilling grill-me grill-with-docs handoff implement implement-spec improve-codebase-architecture pr prototype research retro setup-matt-pocock-skills tdd teach to-questionnaire to-spec to-tickets triage wait-what wayfinder wizard writing-for-agents"
humanlayer_skills := "show-me"
ponytail_plugin := "ponytail@ponytail"

# Install the latest global CLIs, Pi packages, and selected shared skills.
install:
    npm install --global --ignore-scripts {{pi_cli_package}} {{codex_cli_package}}
    for package in {{pi_packages}}; do pi install "$package" || exit 1; done
    npx --yes skills@latest add mattpocock/skills --global --agent pi codex --yes --skill \
        {{mattpocock_skills}}
    npx --yes skills@latest add humanlayer/skills --global --agent pi codex --yes --skill {{humanlayer_skills}}
    codex plugin marketplace add DietrichGebert/ponytail
    codex plugin add {{ponytail_plugin}}
    @echo 'Installed. In Codex, open /hooks to review and trust Ponytail hooks, then start a new thread.'

# Update Pi, all installed Pi packages, and the managed Codex tools and skills.
update:
    npm update --global --ignore-scripts {{codex_cli_package}}
    pi update --all
    npx --yes skills@latest update --global --yes {{mattpocock_skills}} {{humanlayer_skills}}
    codex plugin marketplace upgrade ponytail
    @echo 'Updates complete. Restart Pi to load refreshed packages and skills.'

# Verify real installations in an isolated, disposable Linux container.
test:
    docker build --file tests/Dockerfile --tag ai-setup-test .
    docker run --rm --security-opt=no-new-privileges ai-setup-test
