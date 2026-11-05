import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// No npm dependencies. Reject script errors even when the engine exits with 0.
const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const engine = process.env.GODOT_BIN || 'godot';
const logDirectory = mkdtempSync(join(tmpdir(), 'campus-checks-'));
const checks = [
  ['Import', ['--editor', '--import', '--quit']],
  ['Art', ['--script', 'res://dev/test_art.gd'], 'ALL ART CHECKS PASSED'],
  ['Map', ['res://dev/test_game.tscn'], 'ALL TESTS PASSED'],
  ['Core', ['res://dev/test_core.tscn'], 'ALL CORE CHECKS PASSED'],
  ['Interior', ['--script', 'res://dev/test_interior_transition.gd'], 'ALL INTERIOR CHECKS PASSED'],
];

try {
  for (const [name, args, success] of checks) {
    const log = join(logDirectory, `${name}.log`);
    const result = spawnSync(engine, ['--headless', '--path', project, '--log-file', log, ...args], {
      cwd: project,
      encoding: 'utf8',
      timeout: 60000,
      windowsHide: true,
      maxBuffer: 8 * 1024 * 1024,
    });
    let output = (result.stdout || '') + (result.stderr || '');
    // Also inspect the engine log: console forwarding differs across platforms.
    try { output += '\n' + readFileSync(log, 'utf8'); } catch {}
    if (result.error || result.status !== 0 || /(?:SCRIPT ERROR|ERROR:|\[FAIL\])/.test(output) || (success && !output.includes(success))) {
      throw new Error(`${name} failed: ${result.error?.message || `exit ${result.status}`}\n${output}`);
    }
    console.log(`[PASS] ${name}`);
  }
  console.log('All project checks passed.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  rmSync(logDirectory, { recursive: true, force: true });
}
