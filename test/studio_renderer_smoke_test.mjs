import { mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import ffmpegPath from 'ffmpeg-static';

const repoRoot = resolve(new URL('..', import.meta.url).pathname);
const sourcePath = join(repoRoot, 'api', 'studio-render.js');
const instrumentedPath = join(repoRoot, '.studio-render-smoke.mjs');
const work = await mkdtemp(join(tmpdir(), 'swipess-studio-smoke-'));

function ppm(width, height, rgb) {
  const header = Buffer.from(`P6\n${width} ${height}\n255\n`, 'ascii');
  const pixels = Buffer.alloc(width * height * 3);
  for (let i = 0; i < pixels.length; i += 3) {
    pixels[i] = rgb[0];
    pixels[i + 1] = rgb[1];
    pixels[i + 2] = rgb[2];
  }
  return Buffer.concat([header, pixels]);
}

try {
  const source = await readFile(sourcePath, 'utf8');
  await writeFile(
    instrumentedPath,
    `${source}\nexport { buildFilter, buildSoundtrackWav, renderVideo };\n`,
    'utf8',
  );
  const mod = await import(`${pathToFileURL(instrumentedPath).href}?t=${Date.now()}`);

  const images = [
    join(work, 'one.ppm'),
    join(work, 'two.ppm'),
    join(work, 'three.ppm'),
  ];
  await Promise.all([
    writeFile(images[0], ppm(360, 640, [220, 80, 120])),
    writeFile(images[1], ppm(360, 640, [40, 150, 220])),
    writeFile(images[2], ppm(360, 640, [60, 190, 120])),
  ]);

  const shots = [
    {
      duration: 1.45,
      startScale: 1.04,
      endScale: 1.14,
      startX: -.05,
      startY: .01,
      endX: .05,
      endY: -.01,
      easing: 'easeInOut',
      transition: 'crossFade',
      transitionDuration: .28,
      focalX: .5,
      focalY: .5,
    },
    {
      duration: 1.35,
      startScale: 1.13,
      endScale: 1.04,
      startX: .04,
      startY: -.02,
      endX: -.04,
      endY: .02,
      easing: 'easeOut',
      transition: 'splitVertical',
      transitionDuration: .24,
      focalX: .5,
      focalY: .5,
    },
    {
      duration: 1.4,
      startScale: 1.04,
      endScale: 1.12,
      startX: 0,
      startY: .03,
      endX: 0,
      endY: -.03,
      easing: 'linear',
      transition: 'hardCut',
      transitionDuration: .04,
      focalX: .5,
      focalY: .5,
    },
  ];

  const built = mod.buildFilter(shots);
  if (!built.filter.includes('zoompan=') || !built.filter.includes('xfade=')) {
    throw new Error('Studio filter graph is missing motion or transitions');
  }

  const audioPath = join(work, 'sound.wav');
  const videoPath = join(work, 'studio-smoke.mp4');
  await writeFile(audioPath, mod.buildSoundtrackWav('luxury'));
  const duration = await mod.renderVideo(images, shots, audioPath, videoPath);
  if (!(duration > 2.5 && duration < 5)) {
    throw new Error(`Unexpected Studio duration: ${duration}`);
  }

  const info = await stat(videoPath);
  if (info.size < 30_000) {
    throw new Error(`Studio render is suspiciously small: ${info.size} bytes`);
  }

  const decode = spawnSync(
    ffmpegPath,
    ['-hide_banner', '-loglevel', 'error', '-i', videoPath, '-f', 'null', '-'],
    { encoding: 'utf8', timeout: 120000 },
  );
  if (decode.error || decode.status !== 0) {
    throw new Error(
      `Rendered Studio MP4 failed decode: ${decode.error?.message ?? decode.stderr ?? decode.status}`,
    );
  }

  console.log(`Studio smoke render OK: ${info.size} bytes, ${duration.toFixed(2)}s`);
} finally {
  await Promise.allSettled([
    rm(instrumentedPath, { force: true }),
    rm(work, { recursive: true, force: true }),
  ]);
}
