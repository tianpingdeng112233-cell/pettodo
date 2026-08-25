import path from 'node:path';
import { serve } from '@hono/node-server';
import { createApp } from './app.js';
import { FileArtifactStore } from './artifacts.js';
import { loadConfig } from './config.js';
import { GeminiClient } from './gemini.js';
import { GeminiRigPackPipeline } from './pipeline.js';
import { InProcessHatchQueue } from './queue.js';
import { JsonHatchRepository } from './repository.js';

const config = loadConfig();
const gemini = new GeminiClient(config.geminiApiKey);
const repository = new JsonHatchRepository(path.join(config.dataDir, 'state.json'), {
  globalDailyHatchLimit: config.globalDailyHatchLimit,
});
const artifacts = new FileArtifactStore(path.join(config.dataDir, 'packs'));
const queue = new InProcessHatchQueue();
const app = createApp({
  repository,
  ...(config.publicBaseUrl === undefined ? {} : { publicBaseUrl: config.publicBaseUrl }),
  classifier: gemini,
  pipeline: new GeminiRigPackPipeline(gemini),
  artifacts,
  queue,
});

serve({ fetch: app.fetch, port: config.port }, (info) => {
  console.log(`Pawside hatch backend listening on port ${info.port}`);
});
