import type {
  DetectedSpecies,
  PhotoInput,
  SpeciesClassifier,
  SpeciesResult,
  SupportedSpecies,
} from './types.js';

const GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';
const CLASSIFICATION_MODEL = 'gemini-3.5-flash';
const IMAGE_MODEL = 'gemini-3.1-flash-image';

type FetchLike = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;
type JsonRecord = Record<string, unknown>;

interface InlinePart {
  inline_data: { mime_type: string; data: string };
}

interface TextPart {
  text: string;
}

type RequestPart = InlinePart | TextPart;

export type Box = [number, number, number, number];

export interface FrontBoxes {
  head: Box;
  tail: Box;
  leftFrontLeg: Box;
  rightFrontLeg: Box;
}

export interface SideBoxes {
  head: Box;
  tail: Box;
  frontLeg: Box;
  hindLeg: Box;
}

export const PIXEL_STYLE_PROMPT =
  'Draw this exact pet as a crisp hand-pixeled game sprite: chunky readable pixel clusters, ' +
  'hard stair-stepped edges, no antialiasing, and a restrained warm palette. Reproduce the ' +
  "pet's real markings, proportions, coat, face, eyes, ears, legs, and tail faithfully from " +
  'the attached identity photos. Do not replace observed details with generic breed markings.';

const POSE_PROMPTS = {
  frontOpen:
    'Render this EXACT canonical rig pose: full body, front-facing, sitting upright and centered; ' +
    'eyes open; head straight and level; both ears fully visible with clear background around ' +
    'them; tail curving naturally along the ground around one side of the body, tail tip resting ' +
    'level with the front paws, the whole tail visible and readable against the background; front ' +
    'legs straight and slightly apart.',
  frontClosed:
    'The final attached image is the canonical open-eye sprite. Re-render exactly that same pet, ' +
    'framing, silhouette, body pose, head angle, leg placement, tail placement, lighting, palette, ' +
    'and pixel clusters. Change only the eyes from open to gently closed. Do not move any body part.',
  sleep:
    'Render this EXACT canonical sleep pose: full body curled up asleep in a compact side-on curl, ' +
    'eyes closed, head resting naturally, legs tucked in, and tail visible. Keep the silhouette ' +
    'low-occlusion and readable.',
  side:
    'Render this EXACT canonical side rig pose: full body in strict side view, facing right and ' +
    'standing neutrally; head level; all four feet on one ground line; front and hind legs clearly ' +
    'readable; tail fully visible and separated from the torso.',
} as const;

const BACKGROUND_PROMPT =
  ' Plain solid light-cream background with generous clear space around the entire pet; no shadow, ' +
  'floor, scenery, props, text, or border.';

export interface CanonicalImages {
  frontOpen: Buffer;
  frontClosed: Buffer;
  sleep: Buffer;
  side: Buffer;
}

export class GeminiClient implements SpeciesClassifier {
  constructor(
    private readonly apiKey: string,
    private readonly fetchImpl: FetchLike = fetch,
  ) {
    if (!apiKey) throw new Error('A Gemini API key is required');
  }

  async classifySpecies(photo: PhotoInput): Promise<SpeciesResult> {
    const response = await this.generateContent(CLASSIFICATION_MODEL, [
      photoPart(photo),
      {
        text:
          'Classify the primary animal in this photo. Return species="cat" for a domestic cat, ' +
          'species="dog" for a domestic dog, or species="other" for every other subject. ' +
          'detectedSpecies must be a short lowercase common name for what is visible (for example ' +
          'rabbit, bird, person, or unknown). Do not infer from filenames or surrounding text.',
      },
    ], {
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        required: ['species', 'detectedSpecies'],
        properties: {
          species: { type: 'STRING', enum: ['cat', 'dog', 'other'] },
          detectedSpecies: { type: 'STRING' },
        },
      },
      temperature: 0,
    });

    const parsed = parseJsonText(response) as Partial<SpeciesResult>;
    if (parsed.species !== 'cat' && parsed.species !== 'dog' && parsed.species !== 'other') {
      throw new Error('Gemini returned an invalid species classification');
    }
    const detectedSpecies = cleanDetectedSpecies(parsed.detectedSpecies, parsed.species);
    return { species: parsed.species, detectedSpecies };
  }

  async generateCanonicalImages(photos: PhotoInput[], species: SupportedSpecies): Promise<CanonicalImages> {
    const identityParts = photos.map(photoPart);
    const speciesAnchor = ` The identity reference is a ${species}. `;
    const frontOpen = await this.generateImage([
      ...identityParts,
      { text: PIXEL_STYLE_PROMPT + speciesAnchor + POSE_PROMPTS.frontOpen + BACKGROUND_PROMPT },
    ]);

    const [frontClosed, sleep, side] = await Promise.all([
      this.generateImage([
        ...identityParts,
        { inline_data: { mime_type: 'image/png', data: frontOpen.toString('base64') } },
        { text: PIXEL_STYLE_PROMPT + speciesAnchor + POSE_PROMPTS.frontClosed + BACKGROUND_PROMPT },
      ]),
      this.generateImage([
        ...identityParts,
        { text: PIXEL_STYLE_PROMPT + speciesAnchor + POSE_PROMPTS.sleep + BACKGROUND_PROMPT },
      ]),
      this.generateImage([
        ...identityParts,
        { text: PIXEL_STYLE_PROMPT + speciesAnchor + POSE_PROMPTS.side + BACKGROUND_PROMPT },
      ]),
    ]);

    return { frontOpen, frontClosed, sleep, side };
  }

  async detectFrontBoxes(image: Buffer, width: number, height: number): Promise<FrontBoxes> {
    return this.detectBoxes<FrontBoxes>(image, width, height, [
      'head',
      'tail',
      'leftFrontLeg',
      'rightFrontLeg',
    ], 'front-facing seated pet. The head box must include both ears. Left/right are from the viewer perspective');
  }

  async detectSideBoxes(image: Buffer, width: number, height: number): Promise<SideBoxes> {
    return this.detectBoxes<SideBoxes>(image, width, height, [
      'head',
      'tail',
      'frontLeg',
      'hindLeg',
    ], 'right-facing side-view standing pet. The head box must include the ears');
  }

  private async detectBoxes<T>(
    image: Buffer,
    width: number,
    height: number,
    names: string[],
    viewDescription: string,
  ): Promise<T> {
    const properties = Object.fromEntries(
      names.map((name) => [name, {
        type: 'ARRAY',
        minItems: 4,
        maxItems: 4,
        items: { type: 'INTEGER' },
      }]),
    );
    const response = await this.generateContent(CLASSIFICATION_MODEL, [
      { inline_data: { mime_type: 'image/png', data: image.toString('base64') } },
      {
        text:
          `Locate parts of this ${viewDescription}. The image is exactly ${width}×${height} pixels. ` +
          `Return each box as [x0,y0,x1,y1] in actual image pixel coordinates, never normalized, ` +
          `with 0 <= x0 < x1 <= ${width} and 0 <= y0 < y1 <= ${height}. Boxes should tightly ` +
          'cover the complete visible part.',
      },
    ], {
      responseMimeType: 'application/json',
      responseSchema: { type: 'OBJECT', required: names, properties },
      temperature: 0,
    });
    const parsed = parseJsonText(response) as JsonRecord;
    return Object.fromEntries(
      names.map((name) => [name, validateBox(parsed[name], width, height, name)]),
    ) as T;
  }

  private async generateImage(parts: RequestPart[]): Promise<Buffer> {
    const response = await this.generateContent(IMAGE_MODEL, parts, {
      responseModalities: ['IMAGE'],
    });
    const responseParts = firstCandidateParts(response);
    for (const part of responseParts) {
      const inlineData = isRecord(part) && isRecord(part.inlineData) ? part.inlineData : undefined;
      if (inlineData && typeof inlineData.data === 'string') {
        return Buffer.from(inlineData.data, 'base64');
      }
    }
    throw new Error('Gemini image response did not contain image data');
  }

  private async generateContent(
    model: string,
    parts: RequestPart[],
    generationConfig: JsonRecord,
  ): Promise<unknown> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        const response = await this.fetchImpl(`${GEMINI_ENDPOINT}/${model}:generateContent`, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': this.apiKey,
          },
          body: JSON.stringify({ contents: [{ parts }], generationConfig }),
          signal: AbortSignal.timeout(180_000),
        });
        if (!response.ok) {
          const body = (await response.text()).slice(0, 500);
          throw new Error(`Gemini ${model} failed with ${response.status}: ${body}`);
        }
        return await response.json();
      } catch (error) {
        lastError = error;
        if (attempt < 2) await new Promise((resolve) => setTimeout(resolve, 500 * 2 ** attempt));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('Gemini request failed');
  }
}

function photoPart(photo: PhotoInput): InlinePart {
  return { inline_data: { mime_type: photo.mimeType, data: photo.data.toString('base64') } };
}

function parseJsonText(response: unknown): unknown {
  const part = firstCandidateParts(response).find(
    (candidate) => isRecord(candidate) && typeof candidate.text === 'string',
  );
  if (!isRecord(part) || typeof part.text !== 'string') {
    throw new Error('Gemini response did not contain JSON text');
  }
  const text = part.text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  return JSON.parse(text) as unknown;
}

function firstCandidateParts(response: unknown): unknown[] {
  if (!isRecord(response) || !Array.isArray(response.candidates)) {
    throw new Error('Gemini response did not contain candidates');
  }
  const candidate = response.candidates[0];
  if (!isRecord(candidate) || !isRecord(candidate.content) || !Array.isArray(candidate.content.parts)) {
    throw new Error('Gemini response did not contain candidate parts');
  }
  return candidate.content.parts;
}

function validateBox(value: unknown, width: number, height: number, name: string): Box {
  if (!Array.isArray(value) || value.length !== 4 || value.some((coordinate) => !Number.isFinite(coordinate))) {
    throw new Error(`Gemini returned an invalid ${name} box`);
  }
  const box = value.map((coordinate) => Math.round(Number(coordinate))) as Box;
  const [x0, y0, x1, y1] = box;
  if (x0 < 0 || y0 < 0 || x1 > width || y1 > height || x0 >= x1 || y0 >= y1) {
    throw new Error(`Gemini returned an out-of-bounds ${name} box`);
  }
  return box;
}

function cleanDetectedSpecies(value: unknown, fallback: DetectedSpecies): string {
  if (typeof value !== 'string') return fallback;
  const cleaned = value.trim().toLowerCase().slice(0, 40);
  return cleaned || fallback;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null;
}
