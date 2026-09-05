#!/usr/bin/env bash
# Vercel install: install the pinned video worker dependencies, force the
# Linux/x64 ffmpeg binary that Vercel Functions actually execute, then clone
# Flutter (no SDK on the image) and fetch pub packages.
set -euo pipefail

if [[ -f package-lock.json ]]; then
  npm ci --omit=dev --no-audit --no-fund
else
  npm install --omit=dev --no-audit --no-fund
fi

# ffmpeg-static downloads a platform-specific native binary during install.
# A local `vercel build` on macOS therefore downloads a Mach-O binary, but the
# prebuilt function is later executed on Vercel Linux and dies with exit 126.
# Always package Linux/x64 for Vercel. On a real Linux Vercel build we also
# execute the binary; on macOS we verify the ELF header because a Linux binary
# cannot be executed locally.
if [[ -d node_modules/ffmpeg-static ]]; then
  rm -f node_modules/ffmpeg-static/ffmpeg
  npm_config_platform=linux npm_config_arch=x64 \
    npm rebuild ffmpeg-static --foreground-scripts
fi

node --input-type=module <<'NODE'
import ffmpegPath from 'ffmpeg-static';
import { accessSync, constants, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

if (!ffmpegPath) {
  throw new Error('ffmpeg-static returned no binary path');
}
accessSync(ffmpegPath, constants.R_OK);
const head = readFileSync(ffmpegPath).subarray(0, 4);
const isElf = head[0] === 0x7f && head[1] === 0x45 && head[2] === 0x4c && head[3] === 0x46;
if (!isElf) {
  throw new Error(`Vercel function ffmpeg is not Linux ELF: ${ffmpegPath}`);
}

if (process.platform === 'linux') {
  accessSync(ffmpegPath, constants.X_OK);
  const probe = spawnSync(ffmpegPath, ['-version'], {
    encoding: 'utf8',
    timeout: 15000,
  });
  if (probe.error || probe.status !== 0) {
    throw new Error(
      `ffmpeg Linux preflight failed: ` +
        String(probe.error?.message ?? probe.stderr ?? `exit ${probe.status}`),
    );
  }
  console.log(`[vercel-install] Linux ffmpeg executable OK: ${ffmpegPath}`);
} else {
  console.log(`[vercel-install] Linux ffmpeg ELF packaged from ${process.platform}/${process.arch}: ${ffmpegPath}`);
}
NODE

if [[ ! -x flutter/bin/flutter ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

./flutter/bin/flutter config --no-analytics --enable-web
./flutter/bin/flutter precache --web
./flutter/bin/flutter pub get
