import { randomUUID } from 'node:crypto';
import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import type {
  ArtifactStore,
  HatchQueue,
  HatchRepository,
  PhotoInput,
  RigPackPipeline,
  SpeciesClassifier,
} from './types.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png']);
const MAX_PHOTO_BYTES = 12 * 1024 * 1024;

export interface AppDependencies {
  repository: HatchRepository;
  publicBaseUrl?: string;
  maxUploadBytes?: number;
  classifier: SpeciesClassifier;
  pipeline: RigPackPipeline;
  artifacts: ArtifactStore;
  queue: HatchQueue;
  createId?: () => string;
  logger?: Pick<Console, 'error'>;
}

export function createApp(dependencies: AppDependencies): Hono {
  const app = new Hono();
  const createId = dependencies.createId ?? randomUUID;
  const logger = dependencies.logger ?? console;

  app.get('/health', (context) => context.json({ status: 'ok' }));

  const uploadLimit = bodyLimit({
    maxSize: dependencies.maxUploadBytes ?? 3 * MAX_PHOTO_BYTES + 512 * 1024,
    onError: (context) => context.json({ code: 'payload_too_large' }, 413),
  });

  app.post('/v1/hatch', uploadLimit, async (context) => {
    const rawDeviceId = context.req.header('X-Device-Id');
    if (!rawDeviceId || !UUID_PATTERN.test(rawDeviceId)) {
      return context.json({ code: 'invalid_device_id' }, 401);
    }
    // normalised so hex-case variants cannot mint extra quota buckets
    const deviceId = rawDeviceId.toLowerCase();

    let parsed: Record<string, string | File | (string | File)[]>;
    try {
      parsed = await context.req.parseBody({ all: true });
    } catch (error) {
      // chunked uploads trip the body limit mid-read, inside parseBody
      if (error instanceof Error && /too large/i.test(error.message)) {
        return context.json({ code: 'payload_too_large' }, 413);
      }
      return context.json({ code: 'invalid_request' }, 400);
    }

    const photoValues = arrayOf(parsed['photos[]']).filter(isUploadedFile);
    if (photoValues.length < 1 || photoValues.length > 3) {
      return context.json({ code: 'invalid_photos' }, 400);
    }
    if (photoValues.some((photo) => !ALLOWED_IMAGE_TYPES.has(photo.type) || photo.size > MAX_PHOTO_BYTES)) {
      return context.json({ code: 'invalid_photos' }, 400);
    }
    const petNameValue = parsed.petName;
    if (Array.isArray(petNameValue) || (petNameValue !== undefined && typeof petNameValue !== 'string')) {
      return context.json({ code: 'invalid_pet_name' }, 400);
    }
    const petName = petNameValue?.trim();
    if (petName !== undefined && (petName.length === 0 || petName.length > 80)) {
      return context.json({ code: 'invalid_pet_name' }, 400);
    }

    const availability = dependencies.repository.availability(deviceId);
    if (availability === 'quota_exhausted') {
      return context.json({ code: 'quota_exhausted' }, 402);
    }
    if (availability === 'daily_limit_reached') {
      return context.json({ code: 'daily_limit_reached' }, 503);
    }

    const photos: PhotoInput[] = await Promise.all(photoValues.map(async (photo) => ({
      data: Buffer.from(await photo.arrayBuffer()),
      mimeType: photo.type as PhotoInput['mimeType'],
    })));

    if (!dependencies.repository.consumeDailySlot()) {
      return context.json({ code: 'daily_limit_reached' }, 503);
    }

    let classification;
    try {
      classification = await dependencies.classifier.classifySpecies(photos[0]!);
    } catch (error) {
      logger.error('Species classification failed', error);
      return context.json({ code: 'hatch_unavailable' }, 503);
    }
    if (classification.species === 'other') {
      return context.json({
        code: 'species_unsupported',
        detectedSpecies: classification.detectedSpecies,
      }, 422);
    }
    const supportedSpecies = classification.species;

    const hatchId = createId();
    const reservation = dependencies.repository.reserve({
      id: hatchId,
      deviceId,
      species: supportedSpecies,
      ...(petName === undefined ? {} : { petName }),
    });
    if (!reservation.ok) {
      if (reservation.reason === 'quota_exhausted') {
        return context.json({ code: 'quota_exhausted' }, 402);
      }
      return context.json({ code: 'daily_limit_reached' }, 503);
    }

    dependencies.queue.enqueue(async () => {
      try {
        const pack = await dependencies.pipeline.build({
          hatchId,
          species: supportedSpecies,
          photos,
          ...(petName === undefined ? {} : { petName }),
        });
        const packFile = await dependencies.artifacts.writePack(hatchId, pack);
        dependencies.repository.setJobReady(hatchId, packFile);
      } catch (error) {
        logger.error(`Hatch ${hatchId} failed`, error);
        dependencies.repository.setJobFailed(hatchId);
      }
    });

    return context.json({ hatchId, status: 'incubating' }, 201);
  });

  app.get('/v1/hatch/:id', (context) => {
    const rawDeviceId = context.req.header('X-Device-Id');
    if (!rawDeviceId || !UUID_PATTERN.test(rawDeviceId)) {
      return context.json({ code: 'invalid_device_id' }, 401);
    }
    const deviceId = rawDeviceId.toLowerCase();
    const job = dependencies.repository.getJob(context.req.param('id'), deviceId);
    if (!job) return context.json({ code: 'hatch_not_found' }, 404);
    if (job.status === 'ready' && job.packFile) {
      // behind a reverse proxy the request URL is the internal HTTP hop;
      // PUBLIC_BASE_URL is the externally correct origin
      const origin = dependencies.publicBaseUrl ?? new URL(context.req.url).origin;
      return context.json({
        status: 'ready' as const,
        packUrl: `${origin}/v1/packs/${encodeURIComponent(job.packFile)}`,
      });
    }
    return context.json({ status: job.status });
  });

  app.get('/v1/packs/:fileName', async (context) => {
    const pack = await dependencies.artifacts.readPack(context.req.param('fileName'));
    if (!pack) return context.json({ code: 'pack_not_found' }, 404);
    return context.body(Uint8Array.from(pack), 200, {
      'Content-Type': 'application/zip',
      'Content-Disposition': `attachment; filename="${context.req.param('fileName')}"`,
      'Cache-Control': 'private, max-age=31536000, immutable',
    });
  });

  const wishLimit = bodyLimit({
    maxSize: 4 * 1024,
    onError: (context) => context.json({ code: 'payload_too_large' }, 413),
  });

  app.post('/v1/species-wish', wishLimit, async (context) => {
    let body: unknown;
    try {
      body = await context.req.json();
    } catch {
      return context.json({ code: 'invalid_request' }, 400);
    }
    if (!isRecord(body) || typeof body.speciesText !== 'string') {
      return context.json({ code: 'invalid_request' }, 400);
    }
    const speciesText = body.speciesText.trim();
    if (speciesText.length === 0 || speciesText.length > 80) {
      return context.json({ code: 'invalid_request' }, 400);
    }
    dependencies.repository.addSpeciesWish(speciesText);
    return context.body(null, 204);
  });

  return app;
}

function arrayOf<T>(value: T | T[] | undefined): T[] {
  if (value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

function isUploadedFile(value: string | File): value is File {
  return typeof value !== 'string' && typeof value.arrayBuffer === 'function';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
