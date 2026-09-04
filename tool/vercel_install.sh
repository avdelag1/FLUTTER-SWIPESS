#!/usr/bin/env bash
# Vercel install: install the pinned video worker dependencies, force a fresh
# platform-correct ffmpeg binary for the Vercel Linux build, then clone
# Flutter (no SDK on the image) and fetch pub packages.
set -euo pipefail

if [[ -f package-lock.json ]]; then
  npm ci --omit=dev --no-audit --no-fund
else
  # Keep builds usable during the one-time lockfile bootstrap commit.
  npm install --omit=dev --no-audit --no-fund
fi

# ffmpeg-static downloads a platform/architecture-specific native binary during
# its lifecycle script. A cached or locally-packaged binary from another OS/CPU
# can be present in node_modules and still be bundled into the Vercel Function,
# which then fails at runtime with ffmpeg_exit_126 / cannot execute binary file.
# Remove it, rebuild it on Vercel's Linux build host, and fail the deployment if
# the resulting binary cannot actually execute. That is much safer than shipping
# a deployment that silently leaves every uploaded listing video unprocessed.
if [[ -d node_modules/ffmpeg-static ]]; then
  rm -f node_modules/ffmpeg-static/ffmpeg
  npm rebuild ffmpeg-static --foreground-scripts
fi

node --input-type=module <<'NODE'
import ffmpegPath from 'ffmpeg-static';
import { accessSync, constants } from 'node:fs';
import { spawnSync } from 'node:child_process';

if (!ffmpegPath) {
  throw new Error('ffmpeg-static returned no binary path');
}
accessSync(ffmpegPath, constants.X_OK);
const probe = spawnSync(ffmpegPath, ['-version'], {
  encoding: 'utf8',
  timeout: 15000,
});
if (probe.error || probe.status !== 0) {
  throw new Error(
    `ffmpeg preflight failed on ${process.platform}/${process.arch}: ` +
      String(probe.error?.message ?? probe.stderr ?? `exit ${probe.status}`),
  );
}
console.log(`[vercel-install] ffmpeg OK on ${process.platform}/${process.arch}: ${ffmpegPath}`);
NODE

if [[ ! -x flutter/bin/flutter ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

./flutter/bin/flutter config --no-analytics --enable-web
./flutter/bin/flutter precache --web
./flutter/bin/flutter pub get
