import type { RigJson } from './rig.js';
import type { SupportedSpecies } from './types.js';
import { createFlatZip } from './zip.js';

const POSE_FILE_NAMES = ['front-open.png', 'front-closed.png', 'sleep.png', 'side.png'] as const;

export interface PackJson {
  formatVersion: 3;
  id: string;
  display_name: string;
  species: SupportedSpecies;
  treat: { name: string; emoji: string };
}

export async function buildRigPack(input: {
  hatchId: string;
  petName?: string;
  species: SupportedSpecies;
  images: Record<(typeof POSE_FILE_NAMES)[number], Buffer>;
  rig: RigJson;
}): Promise<Buffer> {
  const displayName = input.petName?.trim() || (input.species === 'cat' ? 'My Cat' : 'My Dog');
  const packJson: PackJson = {
    formatVersion: 3,
    id: `${slugify(displayName, input.species)}-${input.hatchId.slice(0, 8)}`,
    display_name: displayName,
    species: input.species,
    treat: input.species === 'cat'
      ? { name: 'tuna', emoji: '🐟' }
      : { name: 'biscuit', emoji: '🦴' },
  };

  return createFlatZip({
    'pack.json': Buffer.from(JSON.stringify(packJson)),
    'rig.json': Buffer.from(JSON.stringify(input.rig)),
    ...input.images,
  });
}

function slugify(value: string, fallback: string): string {
  const slug = value
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 48);
  return slug || fallback;
}
