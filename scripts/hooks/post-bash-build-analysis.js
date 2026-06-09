#!/usr/bin/env node
// PostToolUse(Bash): after a build/test command, kick off a NON-BLOCKING background
// analysis that writes a short report to .claude/sessions/build-analysis.log. The
// hook returns immediately so it never slows the session.
'use strict';
const { readInput, cwdOf, stateDir, path, fs, os } = require('./_lib.js');
const { spawn } = require('child_process');

const input = readInput();
const cmd = (input.tool_input && input.tool_input.command) || '';
const cwd = cwdOf(input);

const BUILD = /\b(npm run build|pnpm build|yarn build|next build|tsc\b|cargo build|go build|vite build|webpack)\b/;
if (!BUILD.test(cmd)) process.exit(0);

const logDir = stateDir(cwd, 'sessions');
const logFile = path.join(logDir, 'build-analysis.log');
const resp = input.tool_response || {};
const out = typeof resp === 'string' ? resp : (resp.stdout || resp.output || JSON.stringify(resp)).toString();

// Detach a worker that does cheap pattern analysis and appends a report.
const worker = `
const fs=require('fs');
const out=${JSON.stringify(out.slice(0, 20000))};
const warn=(out.match(/warning/gi)||[]).length;
const err=(out.match(/\\berror\\b/gi)||[]).length;
const slow=/(\\d+(\\.\\d+)?)\\s*(s|ms)\\b/.test(out);
const stamp=new Date().toISOString();
const report='['+stamp+'] build analysis\\n  command: ${cmd.replace(/'/g, "")}\\n  errors~'+err+'  warnings~'+warn+'  timing-mentioned:'+slow+'\\n';
try{fs.appendFileSync(${JSON.stringify(logFile)}, report);}catch(e){}
`;
try {
  const child = spawn(process.execPath, ['-e', worker], { detached: true, stdio: 'ignore', cwd });
  child.unref();
} catch {}
process.exit(0);
