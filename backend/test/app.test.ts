import { describe, expect, it, vi } from 'vitest';
import { createApp } from '../src/app.js';
import { InMemoryHatchRepository } from '../src/repository.js';
import type {
  ArtifactStore,
  HatchQueue,
  RigPackPipeline,
  SpeciesClassifier,
  SpeciesResult,
} from '../src/types.js';

const DEVICE_ID = '7dd6429c-2c18-4cf6-9bb1-d228e331ba46';
const OTHER_DEVICE_ID = 'f0495c7d-d914-443d-b9f0-e71726229877';

class ControlledQueue implements HatchQueue {
  readonly tasks: Array<() => Promise<void>> = [];

  enqueue(task: () => Promise<void>): void {
    this.tasks.push(task);
  }

  async runNext(): Promise<void> {
    const task = this.tasks.shift();
    if (!task) throw new Error('No queued task');
    await task();
  }
}

class MemoryArtifacts implements ArtifactStore {
  readonly packs = new Map<string, Buffer>();

  async writePack(hatchId: string, pack: Buffer): Promise<string> {
    const fileName = `${hatchId}.pettodopet`;
    this.packs.set(fileName, pack);
    return fileName;
  }

  async readPack(fileName: string): Promise<Buffer | undefined> {
    return this.packs.get(fileName);
  }
}

function hatchForm(options: { petName?: string; type?: string; count?: number } = {}): FormData {
  const form = new FormData();
  const count = options.count ?? 1;
  for (let index = 0; index < count; index += 1) {
    form.append(
      'photos[]',
      new Blob([`photo-${index}`], { type: options.type ?? 'image/jpeg' }),
      `photo-${index}.jpg`,
    );
  }
  if (options.petName !== undefined) form.append('petName', options.petName);
  return form;
}

function harness(options: {
  species?: SpeciesResult;
  pipeline?: RigPackPipeline;
  dailyLimit?: number;
  publicBaseUrl?: string;
  maxUploadBytes?: number;
} = {}) {
  const repository = new InMemoryHatchRepository({
    globalDailyHatchLimit: options.dailyLimit ?? 200,
  });
  const classifier: SpeciesClassifier = {
    classifySpecies: vi.fn(async () => options.species ?? {
      species: 'cat' as const,
      detectedSpecies: 'cat',
    }),
  };
  const pipeline = options.pipeline ?? {
    build: vi.fn(async () => Buffer.from('rig-pack')),
  };
  const artifacts = new MemoryArtifacts();
  const queue = new ControlledQueue();
  let nextId = 1;
  const app = createApp({
    repository,
    ...(options.publicBaseUrl === undefined ? {} : { publicBaseUrl: options.publicBaseUrl }),
    ...(options.maxUploadBytes === undefined ? {} : { maxUploadBytes: options.maxUploadBytes }),
    classifier,
    pipeline,
    artifacts,
    queue,
    createId: () => `00000000-0000-4000-8000-${String(nextId++).padStart(12, '0')}`,
    logger: { error: vi.fn() },
  });
  return { app, repository, classifier, pipeline, artifacts, queue };
}

async function postHatch(app: ReturnType<typeof createApp>, form = hatchForm(), deviceId = DEVICE_ID) {
  return app.request('/v1/hatch', {
    method: 'POST',
    headers: { 'X-Device-Id': deviceId },
    body: form,
  });
}

describe('hatch API contract', () => {
  it('submits, polls, finishes, and directly downloads a rig pack', async () => {
    const { app, queue } = harness();
    const submitted = await postHatch(app, hatchForm({ petName: 'Miso', count: 3 }));

    expect(submitted.status).toBe(201);
    const submission = await submitted.json() as { hatchId: string; status: string };
    expect(submission).toEqual({
      hatchId: '00000000-0000-4000-8000-000000000001',
      status: 'incubating',
    });

    const incubating = await app.request(`/v1/hatch/${submission.hatchId}`, {
      headers: { 'X-Device-Id': DEVICE_ID },
    });
    expect(await incubating.json()).toEqual({ status: 'incubating' });

    await queue.runNext();
    const ready = await app.request(`https://hatch.example/v1/hatch/${submission.hatchId}`, {
      headers: { 'X-Device-Id': DEVICE_ID },
    });
    expect(await ready.json()).toEqual({
      status: 'ready',
      packUrl: `https://hatch.example/v1/packs/${submission.hatchId}.pettodopet`,
    });

    const download = await app.request(`/v1/packs/${submission.hatchId}.pettodopet`);
    expect(download.status).toBe(200);
    expect(download.headers.get('content-type')).toBe('application/zip');
    expect(Buffer.from(await download.arrayBuffer()).toString()).toBe('rig-pack');
  });

  it('returns 422 before reserving quota for unsupported species', async () => {
    const { app, repository, queue } = harness({
      species: { species: 'other', detectedSpecies: 'rabbit' },
    });
    const response = await postHatch(app);
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({
      code: 'species_unsupported',
      detectedSpecies: 'rabbit',
    });
    expect(repository.availability(DEVICE_ID)).toBe('available');
    expect(queue.tasks).toHaveLength(0);
  });

  it('exposes failed status when queued generation fails', async () => {
    const { app, queue } = harness({
      pipeline: { build: vi.fn(async () => { throw new Error('generation failed'); }) },
    });
    const submitted = await postHatch(app);
    const { hatchId } = await submitted.json() as { hatchId: string };
    await queue.runNext();

    const response = await app.request(`/v1/hatch/${hatchId}`, {
      headers: { 'X-Device-Id': DEVICE_ID },
    });
    expect(await response.json()).toEqual({ status: 'failed' });
  });

  it('validates auth, uploads, ownership, wish input, and daily guard paths', async () => {
    const { app } = harness({ dailyLimit: 1 });
    expect((await app.request('/v1/hatch', { method: 'POST', body: hatchForm() })).status).toBe(401);
    expect((await postHatch(app, hatchForm({ count: 4 }))).status).toBe(400);
    expect((await postHatch(app, hatchForm({ type: 'image/webp' }))).status).toBe(400);

    const accepted = await postHatch(app);
    const { hatchId } = await accepted.json() as { hatchId: string };
    const hidden = await app.request(`/v1/hatch/${hatchId}`, {
      headers: { 'X-Device-Id': OTHER_DEVICE_ID },
    });
    expect(hidden.status).toBe(404);
    expect((await postHatch(app, hatchForm(), OTHER_DEVICE_ID)).status).toBe(503);

    const wish = await app.request('/v1/species-wish', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ speciesText: 'rabbit' }),
    });
    expect(wish.status).toBe(204);
    const invalidWish = await app.request('/v1/species-wish', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ speciesText: '' }),
    });
    expect(invalidWish.status).toBe(400);
  });
});

describe('device quota', () => {
  it('accepts exactly three hatches, then returns contract 402 without calling Gemini', async () => {
    const { app, classifier } = harness();
    for (let attempt = 0; attempt < 3; attempt += 1) {
      expect((await postHatch(app)).status).toBe(201);
    }
    const rejected = await postHatch(app);
    expect(rejected.status).toBe(402);
    expect(await rejected.json()).toEqual({ code: 'quota_exhausted' });
    expect(classifier.classifySpecies).toHaveBeenCalledTimes(3);
  });
});


describe('review hardening', () => {
  it('the final daily budget slot is still usable for a supported species', async () => {
    const { app } = harness({ dailyLimit: 1 });
    expect((await postHatch(app)).status).toBe(201);
    expect((await postHatch(app)).status).toBe(503);
  });

  it('refunds the device quota when a hatch fails server-side', async () => {
    const failingPipeline: RigPackPipeline = {
      build: vi.fn(async () => {
        throw new Error('generation exploded');
      }),
    };
    const { app, queue } = harness({ pipeline: failingPipeline });
    for (let round = 0; round < 5; round += 1) {
      const accepted = await postHatch(app);
      expect(accepted.status).toBe(201);
      await queue.runNext();
    }
  });

  it('unsupported species still consumes the global daily budget', async () => {
    const { app } = harness({
      species: { species: 'other', detectedSpecies: 'rabbit' },
      dailyLimit: 2,
    });
    expect((await postHatch(app)).status).toBe(422);
    expect((await postHatch(app)).status).toBe(422);
    expect((await postHatch(app)).status).toBe(503);
  });

  it('uses PUBLIC_BASE_URL for packUrl when configured', async () => {
    const { app, queue } = harness({ publicBaseUrl: 'https://api.pawside.app' });
    const created = await postHatch(app);
    const { hatchId } = (await created.json()) as { hatchId: string };
    await queue.runNext();
    const status = await app.request(`/v1/hatch/${hatchId}`, {
      headers: { 'X-Device-Id': DEVICE_ID },
    });
    const body = (await status.json()) as { packUrl: string };
    expect(body.packUrl.startsWith('https://api.pawside.app/v1/packs/')).toBe(true);
  });

  it('rejects oversized uploads before parsing', async () => {
    const { app } = harness({ maxUploadBytes: 64 });
    const response = await postHatch(app, hatchForm({ petName: 'x'.repeat(200) }));
    expect(response.status).toBe(413);
    expect(((await response.json()) as { code: string }).code).toBe('payload_too_large');
  });

  it('treats hex-case device id variants as the same quota bucket', async () => {
    const { app } = harness();
    expect((await postHatch(app)).status).toBe(201);
    expect((await postHatch(app)).status).toBe(201);
    expect((await postHatch(app)).status).toBe(201);
    const upper = DEVICE_ID.toUpperCase();
    expect((await postHatch(app, hatchForm(), upper)).status).toBe(402);
  });
});
