import { describe, expect, it, vi } from 'vitest';
import { GeminiClient } from '../src/gemini.js';
import { isValidFrontHeadBox } from '../src/rig.js';

function geminiJson(value: unknown): Response {
  return Response.json({
    candidates: [{ content: { parts: [{ text: JSON.stringify(value) }] } }],
  });
}

describe('Gemini species gate', () => {
  it.each([
    ['cat', 'cat'],
    ['dog', 'dog'],
    ['other', 'rabbit'],
  ] as const)('preserves the %s classification state', async (species, detectedSpecies) => {
    const fetchMock = vi.fn(async (
      _input: string | URL | Request,
      _init?: RequestInit,
    ) => geminiJson({ species, detectedSpecies }));
    const client = new GeminiClient('test-key', fetchMock);

    await expect(client.classifySpecies({
      data: Buffer.from('not-a-real-photo'),
      mimeType: 'image/jpeg',
    })).resolves.toEqual({ species, detectedSpecies });

    expect(fetchMock).toHaveBeenCalledOnce();
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(String(url)).toContain('/gemini-3.5-flash:generateContent');
    expect(init?.headers).toMatchObject({ 'x-goog-api-key': 'test-key' });
    expect(String(init?.body)).toContain('responseMimeType');
  });

  it('rejects classifications outside the three-state seam', async () => {
    const client = new GeminiClient(
      'test-key',
      vi.fn(async () => geminiJson({ species: 'fox', detectedSpecies: 'fox' })),
    );
    await expect(client.classifySpecies({
      data: Buffer.from('photo'),
      mimeType: 'image/png',
    })).rejects.toThrow('invalid species');
  });
});

describe('front head-box geometry gate', () => {
  const content = {
    width: 768,
    height: 1152,
    bounds: [123, 315, 720, 1068] as const,
    topRows: [123, 315, 654, 338] as const,
  };

  it('accepts a box that includes the face and the complete topmost ear rows', () => {
    expect(isValidFrontHeadBox([112, 300, 670, 620], content)).toBe(true);
  });

  it('retries an ears-only result once, then returns an absent head box', async () => {
    const earsOnly = {
      head: [182, 230, 609, 460],
      tail: [550, 650, 720, 1000],
      leftFrontLeg: [280, 650, 390, 1068],
      rightFrontLeg: [430, 650, 540, 1068],
    };
    const fetchMock = vi.fn(async () => geminiJson(earsOnly));
    const client = new GeminiClient('test-key', fetchMock);

    await expect(
      client.detectFrontBoxes(Buffer.from('front-pose'), 768, 1152, content),
    ).resolves.toEqual({ ...earsOnly, head: null });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('retries an out-of-bounds head box once, then returns an absent head box', async () => {
    const outOfBounds = {
      head: [182, 230, 609, 1500],
      tail: [550, 650, 720, 1000],
      leftFrontLeg: [280, 650, 390, 1068],
      rightFrontLeg: [430, 650, 540, 1068],
    };
    const fetchMock = vi.fn(async () => geminiJson(outOfBounds));
    const client = new GeminiClient('test-key', fetchMock);

    await expect(
      client.detectFrontBoxes(Buffer.from('front-pose'), 768, 1152, content),
    ).resolves.toEqual({ ...outOfBounds, head: null });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('clamps a small edge overshoot into the image bounds', async () => {
    const overshoot = {
      head: [182, 340, 609, 620],
      tail: [550, 650, 720, 1000],
      leftFrontLeg: [280, 650, 390, 1160],
      rightFrontLeg: [430, 650, 540, 1068],
    };
    const fetchMock = vi.fn(async () => geminiJson(overshoot));
    const client = new GeminiClient('test-key', fetchMock);

    await expect(
      client.detectFrontBoxes(Buffer.from('front-pose'), 768, 1152),
    ).resolves.toEqual({ ...overshoot, leftFrontLeg: [280, 650, 390, 1152] });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('rescales a per-mille answer into pixel coordinates', async () => {
    const perMille = {
      head: [150, 180, 790, 420],
      tail: [700, 550, 940, 860],
      leftFrontLeg: [360, 560, 500, 920],
      rightFrontLeg: [560, 560, 700, 920],
    };
    const client = new GeminiClient('test-key', vi.fn(async () => geminiJson(perMille)));

    await expect(
      client.detectFrontBoxes(Buffer.from('front-pose'), 768, 1152),
    ).resolves.toEqual({
      head: [115, 207, 607, 484],
      tail: [538, 634, 722, 991],
      leftFrontLeg: [276, 645, 384, 1060],
      rightFrontLeg: [430, 645, 538, 1060],
    });
  });

  it('still rejects an out-of-bounds box for parts that cannot be absent', async () => {
    const badTail = {
      head: [182, 340, 609, 620],
      tail: [550, 650, 1400, 1000],
      leftFrontLeg: [280, 650, 390, 1068],
      rightFrontLeg: [430, 650, 540, 1068],
    };
    const client = new GeminiClient('test-key', vi.fn(async () => geminiJson(badTail)));

    await expect(
      client.detectFrontBoxes(Buffer.from('front-pose'), 768, 1152, content),
    ).rejects.toThrow('out-of-bounds tail box');
  });
});
