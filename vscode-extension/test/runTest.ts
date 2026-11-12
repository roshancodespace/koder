import * as path from 'path';
import { runTests, downloadAndUnzipVSCode } from '@vscode/test-electron';

async function main(): Promise<void> {
  const extensionDevelopmentPath = path.resolve(__dirname, '../../');
  const extensionTestsPath = path.resolve(__dirname, './index');

  let lastErr: unknown;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`Running tests (attempt ${attempt}/3)...`);
      const vscodeExecutablePath = await downloadAndUnzipVSCode({
        version: '1.96.0',
        timeout: 60000,
      });
      await runTests({
        vscodeExecutablePath,
        extensionDevelopmentPath,
        extensionTestsPath,
      });
      return;
    } catch (err) {
      lastErr = err;
      console.warn(`Attempt ${attempt} failed:`, err);
      if (attempt < 3) {
        console.log('Waiting 5s before retrying...');
        await new Promise((r) => setTimeout(r, 5000));
      }
    }
  }

  console.error('All test attempts failed', lastErr);
  process.exit(1);
}

main();
