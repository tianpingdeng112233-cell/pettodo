import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type { ArtifactStore } from './types.js';

const PACK_FILE_PATTERN = /^[0-9a-f-]{36}\.pettodopet$/i;

export class FileArtifactStore implements ArtifactStore {
  constructor(private readonly packsDirectory: string) {}

  async writePack(hatchId: string, pack: Buffer): Promise<string> {
    const fileName = `${hatchId}.pettodopet`;
    if (!PACK_FILE_PATTERN.test(fileName)) throw new Error('Invalid hatch id for pack file');
    await mkdir(this.packsDirectory, { recursive: true });
    const destination = path.join(this.packsDirectory, fileName);
    const temporary = `${destination}.tmp`;
    await writeFile(temporary, pack, { mode: 0o600 });
    await rename(temporary, destination);
    return fileName;
  }

  async readPack(fileName: string): Promise<Buffer | undefined> {
    if (!PACK_FILE_PATTERN.test(fileName)) return undefined;
    try {
      return await readFile(path.join(this.packsDirectory, fileName));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
      throw error;
    }
  }
}
