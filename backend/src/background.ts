import sharp from 'sharp';

export interface ImageGeometry {
  width: number;
  height: number;
  groundY: number;
}

export async function removeSolidBackground(input: Buffer, threshold = 34): Promise<Buffer> {
  const { data, info } = await sharp(input)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { width, height, channels } = info;
  if (channels !== 4) throw new Error('Expected an RGBA image');

  const pixelCount = width * height;
  const visitMarks = new Uint8Array(pixelCount);
  const queue = new Int32Array(pixelCount);
  const removed = new Uint8Array(pixelCount);
  const seeds = [0, width - 1, (height - 1) * width, pixelCount - 1];
  const thresholdSquared = threshold * threshold;

  seeds.forEach((seed, seedIndex) => {
    const mark = seedIndex + 1;
    let head = 0;
    let tail = 0;
    queue[tail++] = seed;
    visitMarks[seed] = mark;
    const seedOffset = seed * channels;
    const red = data[seedOffset] ?? 0;
    const green = data[seedOffset + 1] ?? 0;
    const blue = data[seedOffset + 2] ?? 0;

    while (head < tail) {
      const index = queue[head++];
      if (index === undefined) break;
      const offset = index * channels;
      const dr = (data[offset] ?? 0) - red;
      const dg = (data[offset + 1] ?? 0) - green;
      const db = (data[offset + 2] ?? 0) - blue;
      if (dr * dr + dg * dg + db * db > thresholdSquared) continue;
      removed[index] = 1;

      const x = index % width;
      const y = Math.floor(index / width);
      const neighbors = [
        x > 0 ? index - 1 : -1,
        x + 1 < width ? index + 1 : -1,
        y > 0 ? index - width : -1,
        y + 1 < height ? index + width : -1,
      ];
      for (const neighbor of neighbors) {
        if (neighbor >= 0 && visitMarks[neighbor] !== mark) {
          visitMarks[neighbor] = mark;
          queue[tail++] = neighbor;
        }
      }
    }
  });

  for (let index = 0; index < pixelCount; index += 1) {
    if (removed[index] === 1) data[index * channels + 3] = 0;
  }
  return sharp(data, { raw: info }).png().toBuffer();
}

export async function imageGeometry(image: Buffer): Promise<ImageGeometry> {
  const { data, info } = await sharp(image)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let groundY = -1;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      if ((data[(y * info.width + x) * info.channels + 3] ?? 0) > 16) groundY = y;
    }
  }
  if (groundY < 0) throw new Error('Background removal produced an empty image');
  return { width: info.width, height: info.height, groundY };
}
