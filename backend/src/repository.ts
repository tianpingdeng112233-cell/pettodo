import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import type {
  HatchJob,
  HatchRepository,
  HatchRequest,
  ReservationResult,
} from './types.js';

interface SpeciesWish {
  speciesText: string;
  createdAt: string;
}

interface PersistedState {
  jobs: Record<string, HatchJob>;
  deviceHatchCounts: Record<string, number>;
  dailyHatchCounts: Record<string, number>;
  speciesWishes: SpeciesWish[];
}

const EMPTY_STATE: PersistedState = {
  jobs: {},
  deviceHatchCounts: {},
  dailyHatchCounts: {},
  speciesWishes: [],
};

export interface RepositoryOptions {
  globalDailyHatchLimit: number;
  now?: () => Date;
}

abstract class BaseRepository implements HatchRepository {
  protected state: PersistedState;
  private readonly now: () => Date;
  private readonly globalDailyHatchLimit: number;

  protected constructor(initial: PersistedState, options: RepositoryOptions) {
    this.state = initial;
    this.now = options.now ?? (() => new Date());
    this.globalDailyHatchLimit = options.globalDailyHatchLimit;
  }

  availability(deviceId: string): 'available' | 'quota_exhausted' | 'daily_limit_reached' {
    if ((this.state.deviceHatchCounts[deviceId] ?? 0) >= 3) return 'quota_exhausted';
    if ((this.state.dailyHatchCounts[this.dayKey()] ?? 0) >= this.globalDailyHatchLimit) {
      return 'daily_limit_reached';
    }
    return 'available';
  }

  consumeDailySlot(): boolean {
    // every accepted submission spends Gemini budget (classification runs
    // before reserve), so the global cost guard must count it here
    const day = this.dayKey();
    if ((this.state.dailyHatchCounts[day] ?? 0) >= this.globalDailyHatchLimit) return false;
    this.state.dailyHatchCounts[day] = (this.state.dailyHatchCounts[day] ?? 0) + 1;
    this.persist();
    return true;
  }

  reserve(request: HatchRequest): ReservationResult {
    // the daily slot was already consumed before classification; re-checking
    // it here would make the final slot of the day unusable
    if ((this.state.deviceHatchCounts[request.deviceId] ?? 0) >= 3) {
      return { ok: false, reason: 'quota_exhausted' };
    }

    const timestamp = this.now().toISOString();
    const job: HatchJob = {
      id: request.id,
      deviceId: request.deviceId,
      species: request.species,
      status: 'incubating',
      createdAt: timestamp,
      updatedAt: timestamp,
      ...(request.petName === undefined ? {} : { petName: request.petName }),
    };
    this.state.jobs[job.id] = job;
    this.state.deviceHatchCounts[request.deviceId] =
      (this.state.deviceHatchCounts[request.deviceId] ?? 0) + 1;
    this.persist();
    return { ok: true, job: structuredClone(job) };
  }

  getJob(id: string, deviceId: string): HatchJob | undefined {
    const job = this.state.jobs[id];
    return job?.deviceId === deviceId ? structuredClone(job) : undefined;
  }

  setJobReady(id: string, packFile: string): void {
    const job = this.requireJob(id);
    job.status = 'ready';
    job.packFile = packFile;
    job.updatedAt = this.now().toISOString();
    this.persist();
  }

  setJobFailed(id: string): void {
    const job = this.requireJob(id);
    const alreadyFailed = job.status === 'failed';
    job.status = 'failed';
    delete job.packFile;
    job.updatedAt = this.now().toISOString();
    if (!alreadyFailed) {
      // a server-side failure is not the user's re-hatch: give the slot back
      const count = this.state.deviceHatchCounts[job.deviceId] ?? 0;
      this.state.deviceHatchCounts[job.deviceId] = Math.max(0, count - 1);
    }
    this.persist();
  }

  addSpeciesWish(speciesText: string): void {
    this.state.speciesWishes.push({ speciesText, createdAt: this.now().toISOString() });
    this.persist();
  }

  protected abstract persist(): void;

  private dayKey(): string {
    return this.now().toISOString().slice(0, 10);
  }

  private requireJob(id: string): HatchJob {
    const job = this.state.jobs[id];
    if (!job) throw new Error(`Unknown hatch job: ${id}`);
    return job;
  }
}

export class InMemoryHatchRepository extends BaseRepository {
  constructor(options: RepositoryOptions = { globalDailyHatchLimit: 200 }) {
    super(structuredClone(EMPTY_STATE), options);
  }

  protected persist(): void {}
}

export class JsonHatchRepository extends BaseRepository {
  private readonly filePath: string;

  constructor(filePath: string, options: RepositoryOptions) {
    const state = JsonHatchRepository.read(filePath);
    super(state, options);
    this.filePath = filePath;

    let recovered = false;
    for (const job of Object.values(this.state.jobs)) {
      if (job.status === 'incubating') {
        job.status = 'failed';
        job.updatedAt = new Date().toISOString();
        // a restart-orphaned hatch is a server-side failure: refund the slot
        const count = this.state.deviceHatchCounts[job.deviceId] ?? 0;
        this.state.deviceHatchCounts[job.deviceId] = Math.max(0, count - 1);
        recovered = true;
      }
    }
    if (recovered) this.persist();
  }

  protected persist(): void {
    mkdirSync(path.dirname(this.filePath), { recursive: true });
    const temporaryPath = `${this.filePath}.tmp`;
    writeFileSync(temporaryPath, `${JSON.stringify(this.state, null, 2)}\n`, {
      encoding: 'utf8',
      mode: 0o600,
    });
    renameSync(temporaryPath, this.filePath);
  }

  private static read(filePath: string): PersistedState {
    try {
      const parsed = JSON.parse(readFileSync(filePath, 'utf8')) as Partial<PersistedState>;
      return {
        jobs: parsed.jobs ?? {},
        deviceHatchCounts: parsed.deviceHatchCounts ?? {},
        dailyHatchCounts: parsed.dailyHatchCounts ?? {},
        speciesWishes: parsed.speciesWishes ?? [],
      };
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === 'ENOENT') return structuredClone(EMPTY_STATE);
      throw error;
    }
  }
}
