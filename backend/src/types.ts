export type SupportedSpecies = 'cat' | 'dog';
export type DetectedSpecies = SupportedSpecies | 'other';
export type HatchStatus = 'incubating' | 'ready' | 'failed';

export interface PhotoInput {
  data: Buffer;
  mimeType: 'image/jpeg' | 'image/png';
}

export interface SpeciesResult {
  species: DetectedSpecies;
  detectedSpecies: string;
}

export interface HatchJob {
  id: string;
  deviceId: string;
  petName?: string;
  species: SupportedSpecies;
  status: HatchStatus;
  createdAt: string;
  updatedAt: string;
  packFile?: string;
}

export interface HatchRequest {
  id: string;
  deviceId: string;
  petName?: string;
  species: SupportedSpecies;
}

export type ReservationResult =
  | { ok: true; job: HatchJob }
  | { ok: false; reason: 'quota_exhausted' | 'daily_limit_reached' };

export interface HatchRepository {
  availability(deviceId: string): 'available' | 'quota_exhausted' | 'daily_limit_reached';
  consumeDailySlot(): boolean;
  reserve(request: HatchRequest): ReservationResult;
  getJob(id: string, deviceId: string): HatchJob | undefined;
  setJobReady(id: string, packFile: string): void;
  setJobFailed(id: string): void;
  addSpeciesWish(speciesText: string): void;
}

export interface SpeciesClassifier {
  classifySpecies(photo: PhotoInput): Promise<SpeciesResult>;
}

export interface RigPackPipeline {
  build(input: {
    hatchId: string;
    petName?: string;
    species: SupportedSpecies;
    photos: PhotoInput[];
  }): Promise<Buffer>;
}

export interface ArtifactStore {
  writePack(hatchId: string, pack: Buffer): Promise<string>;
  readPack(fileName: string): Promise<Buffer | undefined>;
}

export interface HatchQueue {
  enqueue(task: () => Promise<void>): void;
}
