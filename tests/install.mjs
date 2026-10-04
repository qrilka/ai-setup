import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

assert.equal(process.env.AI_SETUP_CONTAINER_TEST, '1', 'Run this destructive setup test through just test, not on your host');

function run(command, ...args) {
  return execFileSync(command, args, { encoding: 'utf8', timeout: 600_000 });
}

run('just', '--justfile', '/setup/justfile', 'install');
for (const [command, pkg] of [
  ['pi', '@earendil-works/pi-coding-agent'],
  ['codex', '@openai/codex'],
]) {
  const version = run('npm', 'view', `${pkg}@latest`, 'version').trim();
  assert.ok(run(command, '--version').trim().endsWith(version), `${command} is not latest`);
}
console.log('PASS: latest global CLIs start outside the setup checkout');

const root = run('npm', 'root', '--global').trim();
const { DefaultResourceLoader, getAgentDir } = await import(`${root}/@earendil-works/pi-coding-agent/dist/index.js`);
const loader = new DefaultResourceLoader({ cwd: process.cwd(), agentDir: getAgentDir() });
await loader.reload();
const loaded = loader.getExtensions();
assert.deepEqual(loaded.errors, [], 'Pi extension load errors');
for (const name of ['preview_export', 'ask_user_question', 'web_enable', 'subagents_enable']) {
  assert.ok(loaded.extensions.some(extension => extension.tools.has(name)), `Pi did not register ${name}`);
}
assert.ok(loaded.extensions.some(extension => extension.commands.has('ponytail')), 'Pi did not register Ponytail');
console.log('PASS: all five Pi packages load and register their capabilities');

const expectedSkills = [
  'ask-matt', 'codebase-design', 'code-review', 'diagnosing-bugs', 'domain-modeling',
  'grilling', 'grill-me', 'grill-with-docs', 'handoff', 'implement', 'implement-spec',
  'improve-codebase-architecture', 'pr', 'prototype', 'research', 'retro',
  'setup-matt-pocock-skills', 'tdd', 'teach', 'to-questionnaire', 'to-spec',
  'to-tickets', 'triage', 'wait-what', 'wayfinder', 'wizard', 'writing-for-agents', 'show-me',
];
function checkSkills(skills) {
  for (const name of expectedSkills) {
    assert.equal(skills.filter(skill => skill.name === name).length, 1, `Expected one discoverable ${name}`);
  }
  for (const skill of skills.filter(skill => expectedSkills.includes(skill.name))) {
    assert.ok(skill.enabled !== false, `${skill.name} is disabled`);
  }
  assert.ok(!skills.some(skill => ['solana-dev', 'find-skills'].includes(skill.name)), 'Excluded skills installed');
}
checkSkills(loader.getSkills().skills);
assert.deepEqual(loader.getSkills().diagnostics.filter(diagnostic => diagnostic.type === 'collision'), []);

async function codexSkills() {
  const server = spawn('codex', ['app-server'], { stdio: ['pipe', 'pipe', 'inherit'] });
  const deadline = setTimeout(() => server.kill('SIGKILL'), 60_000);
  const lines = createInterface({ input: server.stdout });
  const send = message => server.stdin.write(`${JSON.stringify(message)}\n`);
  try {
    send({ id: 1, method: 'initialize', params: { clientInfo: { name: 'ai-setup-test', version: '1' } } });
    for await (const line of lines) {
      const response = JSON.parse(line);
      if (response.id === 1) {
        assert.ok(!response.error, JSON.stringify(response.error));
        send({ method: 'initialized' });
        send({ id: 2, method: 'skills/list', params: { cwds: [process.cwd()], forceReload: true } });
      }
      if (response.id === 2) {
        assert.ok(!response.error, JSON.stringify(response.error));
        assert.deepEqual(response.result.data.flatMap(entry => entry.errors), []);
        return response.result.data.flatMap(entry => entry.skills);
      }
    }
    assert.fail('Codex exited or timed out before returning discovered skills');
  } finally {
    clearTimeout(deadline);
    lines.close();
    server.kill();
  }
}
const codexDiscovered = await codexSkills();
checkSkills(codexDiscovered);
console.log('PASS: both agents discover all 28 selected global skills without duplicates');

const plugins = JSON.parse(run('codex', 'plugin', 'list', '--json'));
const ponytail = plugins.installed.filter(plugin => plugin.pluginId === 'ponytail@ponytail');
assert.equal(ponytail.length, 1, 'Expected one Ponytail plugin');
assert.ok(ponytail[0].enabled, 'Ponytail plugin is disabled');
for (const name of ['ponytail', 'ponytail-review', 'ponytail-audit', 'ponytail-debt', 'ponytail-gain', 'ponytail-help']) {
  assert.equal(codexDiscovered.filter(skill => skill.name === `ponytail:${name}` && skill.enabled && skill.pluginId === 'ponytail@ponytail').length, 1, `Codex did not discover ${name}`);
  assert.equal(loader.getSkills().skills.filter(skill => skill.name === name).length, 1, `Pi did not discover ${name}`);
}
console.log('PASS: Ponytail is enabled in Codex and both agents discover its six skills');

const home = homedir();
const settingsPath = join(home, '.pi/agent/settings.json');
const settings = JSON.parse(readFileSync(settingsPath, 'utf8'));
settings.theme = 'light';
settings.customSentinel = { keep: true };
writeFileSync(settingsPath, JSON.stringify(settings));
const configPath = join(home, '.codex/config.toml');
writeFileSync(configPath, `${readFileSync(configPath, 'utf8')}\n[profiles.sentinel]\nmodel = "preserve-me"\n`);
const preserved = new Map([
  [join(home, '.pi/agent/auth.json'), '{"sentinel":{"type":"api_key","key":"dummy-not-real"}}\n'],
  [join(home, '.codex/auth.json'), '{"OPENAI_API_KEY":"dummy-not-real"}\n'],
  [join(home, '.agents/skills/custom-sentinel/SKILL.md'), '---\nname: custom-sentinel\ndescription: Preserve this unrelated skill.\n---\nCustom instructions.\n'],
]);
for (const [path, content] of preserved) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}
const configBefore = readFileSync(configPath, 'utf8');
run('just', '--justfile', '/setup/justfile', 'install');
run('just', '--justfile', '/setup/justfile', 'update');
console.log('PASS: just update completed');
for (const [path, content] of preserved) assert.equal(readFileSync(path, 'utf8'), content, `Changed ${path}`);
assert.equal(readFileSync(configPath, 'utf8'), configBefore, 'Changed unrelated Codex configuration');
const settingsAfter = JSON.parse(readFileSync(settingsPath, 'utf8'));
assert.equal(settingsAfter.theme, 'light');
assert.deepEqual(settingsAfter.customSentinel, { keep: true });
assert.equal(new Set(settingsAfter.packages.map(pkg => typeof pkg === 'string' ? pkg : pkg.source)).size, settingsAfter.packages.length);
await loader.reload();
assert.deepEqual(loader.getExtensions().errors, []);
checkSkills(loader.getSkills().skills);
const codexSkillsAfterRerun = await codexSkills();
checkSkills(codexSkillsAfterRerun);
for (const skills of [loader.getSkills().skills, codexSkillsAfterRerun]) {
  assert.equal(skills.filter(skill => skill.name === 'custom-sentinel').length, 1);
}
assert.equal(JSON.parse(run('codex', 'plugin', 'list', '--json')).installed.filter(plugin => plugin.pluginId === 'ponytail@ponytail' && plugin.enabled).length, 1);
console.log('PASS: rerun preserves unrelated settings, credentials, and skills without duplicating managed resources');
