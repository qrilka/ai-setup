import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [piPackage, homeFiles] = process.argv.slice(2);
assert.ok(piPackage && homeFiles, 'Usage: node tests/pi-extensions.mjs PI_PACKAGE HOME_MANAGER_FILES');
const home = mkdtempSync(join(tmpdir(), 'ai-setup-extensions-'));
process.env.HOME = home;
delete process.env.PI_CODING_AGENT_DIR;
process.env.XDG_CONFIG_HOME = join(home, '.config');
process.env.XDG_CACHE_HOME = join(home, '.cache');
const agentDir = join(home, '.pi/agent');
const extensionDir = join(agentDir, 'extensions');
const tools = new Map([
  ['pi-markdown-preview', 'preview_export'],
  ['rpiv-ask-user-question', 'ask_user_question'],
  ['pi-web-access', 'web_enable'],
  ['pi-subagents', 'subagents_enable'],
]);
try {
  mkdirSync(extensionDir, { recursive: true });
  const unrelated = 'export default function(pi) { pi.registerTool({ name: "unrelated_tool", description: "sentinel", parameters: { type: "object", properties: {} }, execute: async () => ({ content: [], details: undefined }) }); }\n';
  const unrelatedPath = join(extensionDir, 'unrelated.ts');
  writeFileSync(unrelatedPath, unrelated);
  const settings = '{"theme":"light","customSentinel":{"keep":true},"packages":[]}\n';
  const settingsPath = join(agentDir, 'settings.json');
  writeFileSync(settingsPath, settings);
  for (const name of tools.keys()) {
    const source = realpathSync(join(homeFiles, '.pi/agent/extensions', name));
    symlinkSync(source, join(extensionDir, name));
    assert.ok(readFileSync(join(source, 'package.json'), 'utf8'));
    // Neither direct nor nested runtime dependencies may contain a private Pi.
    function checkPeers(directory) {
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = join(directory, entry.name);
        if (entry.name === 'node_modules') {
          for (const peer of ['@earendil-works/pi-ai', '@earendil-works/pi-agent-core', '@earendil-works/pi-coding-agent', '@earendil-works/pi-tui', 'typebox']) {
            assert.ok(!existsSync(join(path, peer)), `Private host peer: ${path}/${peer}`);
          }
        }
        if (entry.isDirectory()) checkPeers(path);
      }
    }
    checkPeers(source);
  }
  const { DefaultResourceLoader, getAgentDir } = await import(`${piPackage}/lib/pi/node_modules/@earendil-works/pi-coding-agent/dist/index.js`);
  assert.equal(getAgentDir(), agentDir, 'Pi must keep its conventional agent directory');
  const loader = new DefaultResourceLoader({ cwd: home, agentDir });
  await loader.reload();
  const loaded = loader.getExtensions();
  assert.deepEqual(loaded.errors, [], 'Pi extension load errors');
  for (const name of [...tools.values(), 'unrelated_tool']) {
    assert.equal(loaded.extensions.filter(extension => extension.tools.has(name)).length, 1, `Expected one registration of ${name}`);
  }
  assert.equal(readFileSync(settingsPath, 'utf8'), settings, 'Changed user settings');
  assert.equal(readFileSync(unrelatedPath, 'utf8'), unrelated, 'Changed unrelated extension');
  console.log('PASS: four Nix extensions load once with host Pi peers; unrelated settings/extension preserved');
} finally {
  rmSync(home, { recursive: true, force: true });
}
