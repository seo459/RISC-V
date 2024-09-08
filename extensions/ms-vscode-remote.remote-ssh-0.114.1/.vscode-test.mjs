//@ts-check

import { defineConfig } from '@vscode/test-cli';

export default defineConfig({
	version: 'insiders-unreleased',
	files: './out-test/test/*.test.js',
	launchArgs: ['--profile-temp'],
	workspaceFolder: 'src/test-fixtures',
});
