import assert from 'node:assert/strict';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readlinkSync, renameSync, symlinkSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const [generation, piPackage, previousCatalog] = process.argv.slice(2);
const home = process.env.HOME;
assert.ok(home === '/build/ai-setup-home', 'Run through the sandboxed Nix check, never on a real home');
const workspace = '/build/ai-setup-workspace';
mkdirSync(workspace, { recursive: true });
const codexDir = join(home, '.codex');
const catalogPath = join(home, '.agents/plugins/marketplace.json');
const configPath = join(codexDir, 'config.toml');
mkdirSync(codexDir, { recursive: true });
mkdirSync(join(home, '.agents/plugins'), { recursive: true });
const marketplaceRoot = join(home, 'sentinel-marketplace');
mkdirSync(join(marketplaceRoot, '.agents/plugins'), { recursive: true });
writeFileSync(join(marketplaceRoot, '.agents/plugins/marketplace.json'), '{"name":"sentinel","plugins":[]}\n');
const config = `model = "sentinel-model"\n[plugins."ponytail@ponytail"]\nenabled = true\n[plugins."unrelated@user"]\nenabled = true\n[marketplaces.sentinel]\nsource_type = "local"\nsource = "${marketplaceRoot}"\n`;
const catalog = '{"name":"personal-sentinel","plugins":[]}\n';
writeFileSync(configPath, config);
writeFileSync(catalogPath, catalog);
const activate = () => spawnSync(`${generation}/activate`, ['--driver-version', '1'], { encoding: 'utf8', cwd: home });
// Even a configured HM backup must not hide replacement of a personal catalog.
process.env.HOME_MANAGER_BACKUP_EXT = 'backup';
let result = activate();
assert.notEqual(result.status, 0, 'Personal catalog conflict must stop activation');
assert.match(result.stdout + result.stderr, /personal plugin catalog/i);
assert.equal(readFileSync(catalogPath, 'utf8'), catalog, 'Changed personal catalog');
assert.equal(readFileSync(configPath, 'utf8'), config, 'Changed settings before conflict was resolved');
console.log('PASS: conflicting personal catalog stops activation before writes');
// Simulate the documented human reconciliation, preserving the original file.
renameSync(catalogPath, `${catalogPath}.saved`);
// A Home Manager-shaped link does not prove its personal entries are retained.
const previousCatalogPath = join(previousCatalog, '.agents/plugins/marketplace.json');
const previousCatalogContent = readFileSync(previousCatalogPath, 'utf8');
symlinkSync(previousCatalogPath, catalogPath);
result = activate();
assert.notEqual(result.status, 0, 'Losing an unrelated catalog plugin must stop activation');
assert.match(result.stdout + result.stderr, /personal plugin catalog/i);
assert.equal(readlinkSync(catalogPath), previousCatalogPath, 'Replaced personal catalog symlink');
assert.equal(readFileSync(catalogPath, 'utf8'), previousCatalogContent, 'Changed linked personal catalog');
assert.equal(readFileSync(configPath, 'utf8'), config, 'Changed settings before linked catalog was reconciled');
console.log('PASS: Home Manager-owned catalog with missing unrelated entries stops activation before writes');
unlinkSync(catalogPath);
const authPath = join(codexDir, 'auth.json');
const auth = '{"OPENAI_API_KEY":"dummy-not-real"}\n';
writeFileSync(authPath, auth);
for (let pass = 0; pass < 2; pass++) {
  result = activate();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(readFileSync(authPath, 'utf8'), auth, 'Changed credentials');
  assert.equal(readFileSync(`${catalogPath}.saved`, 'utf8'), catalog, 'Changed saved catalog');
  const settings = JSON.parse(execFileSync('jaq', ['--from', 'toml', '--to', 'json', '.', configPath], { encoding: 'utf8' }));
  assert.equal(settings.model, 'sentinel-model');
  assert.equal(settings.plugins['unrelated@user'].enabled, true);
  assert.equal(settings.marketplaces.sentinel.source, marketplaceRoot);
  assert.equal(settings.plugins['ponytail@ponytail'].enabled, false);
  assert.equal(settings.plugins['ponytail@home-manager'].enabled, true);
}
const managedCatalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
assert.equal(managedCatalog.name, 'home-manager');
const pluginRoot = join(home, managedCatalog.plugins.find(p => p.name === 'ponytail').source.path);
const manifest = JSON.parse(readFileSync(join(pluginRoot, '.codex-plugin/plugin.json'), 'utf8'));
assert.equal(manifest.name, 'ponytail');
assert.ok(existsSync(join(pluginRoot, manifest.interface.logo)));
assert.ok(existsSync(join(pluginRoot, manifest.hooks)));
execFileSync('bash', ['--noprofile', '--norc', '-c', 'export PATH="$1"; node --version', 'ai-setup-test', `${generation}/home-path/bin`]);
process.env.PATH = `${generation}/home-path/bin:${process.env.PATH}`;
const plugins = JSON.parse(execFileSync('codex', ['plugin', 'list', '--json'], { cwd: workspace, encoding: 'utf8' }));
assert.equal(plugins.installed.filter(p => p.pluginId === 'ponytail@home-manager' && p.enabled).length, 1, JSON.stringify(plugins));
assert.ok(!plugins.installed.some(p => p.pluginId === 'ponytail@ponytail' && p.enabled));

const names = ['ponytail', 'ponytail-review', 'ponytail-audit', 'ponytail-debt', 'ponytail-gain', 'ponytail-help'];
const { DefaultResourceLoader } = await import(`${piPackage}/lib/pi/node_modules/@earendil-works/pi-coding-agent/dist/index.js`);
const loader = new DefaultResourceLoader({ cwd: home, agentDir: join(home, '.pi/agent') });
await loader.reload();
assert.deepEqual(loader.getExtensions().errors, []);
assert.equal(loader.getExtensions().extensions.filter(e => e.commands.has('ponytail')).length, 1);
for (const name of names) assert.equal(loader.getSkills().skills.filter(s => s.name === name).length, 1, `Pi skill ${name}`);

const server = spawn('codex', ['app-server'], { cwd: workspace, stdio: ['pipe', 'pipe', 'inherit'] });
const deadline = setTimeout(() => server.kill('SIGKILL'), 60_000);
const lines = createInterface({ input: server.stdout });
const send = message => server.stdin.write(`${JSON.stringify(message)}\n`);
const responses = new Map();
try {
  send({ id: 1, method: 'initialize', params: { clientInfo: { name: 'ai-setup-test', version: '1' }, capabilities: { experimentalApi: true } } });
  for await (const line of lines) {
    const response = JSON.parse(line);
    if (!response.id) continue;
    assert.ok(!response.error, JSON.stringify(response.error));
    if (response.id === 1) {
      send({ method: 'initialized' });
      send({ id: 2, method: 'skills/list', params: { cwds: [workspace], forceReload: true } });
      send({ id: 3, method: 'hooks/list', params: { cwds: [workspace] } });
      send({ id: 4, method: 'plugin/read', params: { marketplacePath: catalogPath, pluginName: 'ponytail' } });
    } else {
      responses.set(response.id, response.result);
      if (responses.size === 3) break;
    }
  }
  assert.equal(responses.size, 3, 'Codex exited/timed out before discovery');
  assert.equal(responses.get(4).plugin.summary.localVersion, manifest.version);
  assert.deepEqual(responses.get(2).data.flatMap(e => e.errors), []);
  const skills = responses.get(2).data.flatMap(e => e.skills);
  for (const name of names) assert.equal(skills.filter(s => s.name === `ponytail:${name}` && s.enabled && s.pluginId === 'ponytail@home-manager').length, 1, `Codex skill ${name}`);
  const hookEntries = responses.get(3).data;
  assert.deepEqual(hookEntries.flatMap(e => e.errors), []);
  const hooks = hookEntries.flatMap(e => e.hooks).filter(h => h.pluginId === 'ponytail@home-manager');
  assert.deepEqual(hookEntries.flatMap(e => e.warnings), []);
  assert.deepEqual(hooks.map(h => h.eventName).sort(), ['sessionStart', 'subagentStart', 'userPromptSubmit']);
  for (const hook of hooks) {
    assert.equal(hook.source, 'plugin');
    assert.equal(hook.isManaged, false);
    assert.equal(hook.trustStatus, 'untrusted', 'Hook trust must remain manual');
  }
  console.log('PASS: activation merges settings, disables old Ponytail, and preserves credentials; Pi/Codex discover six skills and Codex leaves hooks untrusted');
} finally {
  clearTimeout(deadline);
  lines.close();
  server.kill();
}
