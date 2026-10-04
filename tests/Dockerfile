FROM node:22-trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends bubblewrap ca-certificates git just \
    && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home tester
ENV HOME=/home/tester NPM_CONFIG_PREFIX=/home/tester/.local AI_SETUP_CONTAINER_TEST=1 DO_NOT_TRACK=1
ENV PATH=/home/tester/.local/bin:$PATH
# Fail bounded network checks rather than hanging on an unreachable registry.
ENV NPM_CONFIG_FETCH_TIMEOUT=30000 NPM_CONFIG_FETCH_RETRIES=1
COPY --chown=tester:tester . /setup
USER tester
WORKDIR /home/tester
CMD ["node", "/setup/tests/install.mjs"]
