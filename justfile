# Install the latest global CLIs, Pi packages, and selected shared skills.
install:
    npm install --global --ignore-scripts @earendil-works/pi-coding-agent@latest @openai/codex@latest
    pi install npm:pi-markdown-preview
    pi install npm:@juicesharp/rpiv-ask-user-question
    pi install npm:pi-web-access
    pi install npm:pi-subagents
    pi install git:github.com/DietrichGebert/ponytail
    npx --yes skills@latest add mattpocock/skills --global --agent pi codex --yes --skill \
        ask-matt codebase-design code-review diagnosing-bugs domain-modeling \
        grilling grill-me grill-with-docs handoff implement implement-spec \
        improve-codebase-architecture pr prototype research retro \
        setup-matt-pocock-skills tdd teach to-questionnaire to-spec to-tickets \
        triage wait-what wayfinder wizard writing-for-agents
    npx --yes skills@latest add humanlayer/skills --global --agent pi codex --yes --skill show-me
    codex plugin marketplace add DietrichGebert/ponytail
    codex plugin add ponytail@ponytail
    @echo 'Installed. In Codex, open /hooks to review and trust Ponytail hooks, then start a new thread.'

# Verify real installations in an isolated, disposable Linux container.
test:
    docker build --file tests/Dockerfile --tag ai-setup-test .
    docker run --rm --security-opt=no-new-privileges ai-setup-test
