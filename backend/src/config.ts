import path from 'node:path';

export interface BackendConfig {
  port: number;
  dataDir: string;
  globalDailyHatchLimit: number;
  geminiApiKey: string;
  publicBaseUrl?: string;
}

function positiveInteger(value: string | undefined, fallback: number, name: string): number {
  if (value === undefined) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): BackendConfig {
  const geminiApiKey = env.GEMINI_API_KEY;
  if (!geminiApiKey) {
    throw new Error('GEMINI_API_KEY is required');
  }

  return {
    port: positiveInteger(env.PORT, 3000, 'PORT'),
    dataDir: path.resolve(env.DATA_DIR ?? './data'),
    globalDailyHatchLimit: positiveInteger(
      env.GLOBAL_DAILY_HATCH_LIMIT,
      200,
      'GLOBAL_DAILY_HATCH_LIMIT',
    ),
    geminiApiKey,
    ...(env.PUBLIC_BASE_URL === undefined ? {} : { publicBaseUrl: validBaseUrl(env.PUBLIC_BASE_URL) }),
  };
}

function validBaseUrl(value: string): string {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('PUBLIC_BASE_URL must be an absolute http(s) URL');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('PUBLIC_BASE_URL must use http or https');
  }
  return parsed.origin;
}
