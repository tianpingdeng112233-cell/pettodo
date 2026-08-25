import { describe, expect, it, vi } from 'vitest';
import { GeminiClient } from '../src/gemini.js';

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
