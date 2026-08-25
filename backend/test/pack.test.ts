import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { removeSolidBackground } from '../src/background.js';
import { buildRigPack } from '../src/pack.js';
import { buildRig } from '../src/rig.js';

async function rgbaFixture(): Promise<Buffer> {
  return sharp({
    create: { width: 8, height: 8, channels: 4, background: { r: 90, g: 50, b: 30, alpha: 0.8 } },
  }).png().toBuffer();
}

describe('rig pack v3 contract', () => {
  it('writes only the six flat contract entries with valid metadata and RGBA poses', async () => {
    const image = await rgbaFixture();
    const rig = buildRig({
      frontGroundY: 7,
      frontBoxes: {
        head: [2, 0, 6, 3],
        tail: [6, 3, 8, 7],
        leftFrontLeg: [2, 3, 3, 7],
        rightFrontLeg: [5, 3, 6, 7],
      },
      sideGroundY: 7,
      sideBoxes: {
        head: [5, 0, 8, 3],
        tail: [0, 2, 2, 6],
        frontLeg: [5, 3, 6, 7],
        hindLeg: [2, 3, 3, 7],
      },
    });
    const buffer = await buildRigPack({
      hatchId: '12345678-1234-4123-8123-123456789abc',
      petName: 'Miso Cat',
      species: 'cat',
      images: {
        'front-open.png': image,
        'front-closed.png': image,
        'sleep.png': image,
        'side.png': image,
      },
      rig,
    });

    const files = readStoredZip(buffer);
    expect([...files.keys()].sort()).toEqual([
      'front-closed.png',
      'front-open.png',
      'pack.json',
      'rig.json',
      'side.png',
      'sleep.png',
    ]);
    expect([...files.keys()].every((name) => !name.includes('/'))).toBe(true);
    const packJson = JSON.parse(files.get('pack.json')!.toString()) as Record<string, unknown>;
    expect(packJson).toEqual({
      formatVersion: 3,
      id: 'miso-cat-12345678',
      display_name: 'Miso Cat',
      species: 'cat',
      treat: { name: 'tuna', emoji: '🐟' },
    });
    expect(JSON.parse(files.get('rig.json')!.toString())).toEqual(rig);
    for (const name of ['front-open.png', 'front-closed.png', 'sleep.png', 'side.png']) {
      const metadata = await sharp(files.get(name)!).metadata();
      expect(metadata.channels).toBe(4);
      expect(metadata.format).toBe('png');
    }
  });

  it('derives pivots from box geometry in pixel coordinates', () => {
    const rig = buildRig({
      frontGroundY: 1130,
      frontBoxes: {
        head: [300, 100, 700, 500],
        tail: [800, 500, 1100, 1000],
        leftFrontLeg: [350, 500, 450, 1100],
        rightFrontLeg: [550, 500, 650, 1100],
      },
      sideGroundY: 1130,
      sideBoxes: {
        head: [700, 100, 1100, 500],
        tail: [50, 450, 350, 850],
        frontLeg: [750, 500, 850, 1100],
        hindLeg: [400, 500, 500, 1100],
      },
    });
    expect(rig.front.pivots).toEqual({ head: [500, 500], tail: [800, 750] });
    expect(rig.side.pivots).toEqual({
      head: [900, 500],
      tail: [350, 650],
      frontLeg: [800, 500],
      hindLeg: [450, 500],
    });
  });
});

function readStoredZip(zip: Buffer): Map<string, Buffer> {
  const files = new Map<string, Buffer>();
  let offset = 0;
  while (zip.readUInt32LE(offset) === 0x04034b50) {
    const method = zip.readUInt16LE(offset + 8);
    if (method !== 0) throw new Error('Test parser only accepts stored entries');
    const size = zip.readUInt32LE(offset + 18);
    const nameLength = zip.readUInt16LE(offset + 26);
    const extraLength = zip.readUInt16LE(offset + 28);
    const nameStart = offset + 30;
    const dataStart = nameStart + nameLength + extraLength;
    const name = zip.subarray(nameStart, nameStart + nameLength).toString('utf8');
    files.set(name, zip.subarray(dataStart, dataStart + size));
    offset = dataStart + size;
  }
  return files;
}

describe('solid background removal', () => {
  it('flood-fills the connected corner color while preserving the subject', async () => {
    const width = 5;
    const height = 5;
    const pixels = Buffer.alloc(width * height * 3, 240);
    for (let y = 1; y <= 3; y += 1) {
      for (let x = 1; x <= 3; x += 1) {
        const offset = (y * width + x) * 3;
        pixels[offset] = 30;
        pixels[offset + 1] = 20;
        pixels[offset + 2] = 10;
      }
    }
    const input = await sharp(pixels, { raw: { width, height, channels: 3 } }).png().toBuffer();
    const output = await removeSolidBackground(input, 10);
    const { data, info } = await sharp(output).raw().toBuffer({ resolveWithObject: true });
    expect(info.channels).toBe(4);
    expect(data[3]).toBe(0);
    expect(data[(2 * width + 2) * 4 + 3]).toBe(255);
  });
});


describe('tail pivot body-side derivation', () => {
  it('judges the body side against the head box, not the canvas centre', async () => {
    const { buildRig } = await import('../src/rig.js');
    // sprite pushed far right on a wide canvas: canvas-centre logic would pick
    // the tail's right edge (nearer canvas centre from the left), head-centre
    // logic must pick the edge nearest the head
    const rig = buildRig({
      frontGroundY: 40,
      frontBoxes: {
        head: [210, 4, 230, 20],
        tail: [232, 15, 240, 31],
        leftFrontLeg: [212, 20, 218, 40],
        rightFrontLeg: [222, 20, 228, 40],
      },
      sideGroundY: 40,
      sideBoxes: {
        head: [225, 5, 242, 21],
        tail: [202, 12, 212, 30],
        frontLeg: [228, 21, 234, 40],
        hindLeg: [212, 21, 218, 40],
      },
    });
    expect(rig.front.pivots.tail[0]).toBe(232);
    expect(rig.side.pivots.tail[0]).toBe(212);
  });
});
