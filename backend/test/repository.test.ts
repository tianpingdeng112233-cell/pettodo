import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { JsonHatchRepository } from '../src/repository.js';

const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(temporaryDirectories.splice(0).map((directory) => rm(directory, {
    recursive: true,
    force: true,
  })));
});

describe('JSON hatch state', () => {
  it('persists quota and ready job status across repository instances', async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), 'pawside-hatch-state-'));
    temporaryDirectories.push(directory);
    const filePath = path.join(directory, 'state.json');
    const now = () => new Date('2026-08-25T12:00:00.000Z');
    const first = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200, now });
    expect(first.consumeDailySlot()).toBe(true);
    const reservation = first.reserve({
      id: 'job-1',
      deviceId: 'device-1',
      species: 'dog',
      petName: 'Pippin',
    });
    expect(reservation.ok).toBe(true);
    first.setJobReady('job-1', 'job-1.pettodopet');

    const second = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200, now });
    expect(second.getJob('job-1', 'device-1')).toMatchObject({
      status: 'ready',
      packFile: 'job-1.pettodopet',
    });
    expect(JSON.parse(await readFile(filePath, 'utf8'))).toMatchObject({
      deviceHatchCounts: { 'device-1': 1 },
      dailyHatchCounts: { '2026-08-25': 1 },
    });
  });

  it('marks an interrupted in-memory queue job failed on restart', async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), 'pawside-hatch-recovery-'));
    temporaryDirectories.push(directory);
    const filePath = path.join(directory, 'state.json');
    const first = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200 });
    first.reserve({ id: 'job-2', deviceId: 'device-2', species: 'cat' });

    const restarted = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200 });
    expect(restarted.getJob('job-2', 'device-2')?.status).toBe('failed');
  });
});


describe('restart recovery', () => {
  it('refunds the device slot for hatches orphaned by a restart', async () => {
    const { mkdtempSync } = await import('node:fs');
    const os = await import('node:os');
    const path = (await import('node:path')).default;
    const { JsonHatchRepository } = await import('../src/repository.js');
    const directory = mkdtempSync(path.join(os.tmpdir(), 'pawside-restart-'));
    const filePath = path.join(directory, 'state.json');
    const first = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200 });
    first.consumeDailySlot();
    first.reserve({ id: 'job-r', deviceId: 'device-r', species: 'cat' });
    expect(first.availability('device-r')).toBe('available');

    const restarted = new JsonHatchRepository(filePath, { globalDailyHatchLimit: 200 });
    expect(restarted.getJob('job-r', 'device-r')?.status).toBe('failed');
    // slot refunded: three fresh hatches must still be possible
    restarted.consumeDailySlot();
    expect(restarted.reserve({ id: 'r1', deviceId: 'device-r', species: 'cat' }).ok).toBe(true);
    restarted.consumeDailySlot();
    expect(restarted.reserve({ id: 'r2', deviceId: 'device-r', species: 'cat' }).ok).toBe(true);
    restarted.consumeDailySlot();
    expect(restarted.reserve({ id: 'r3', deviceId: 'device-r', species: 'cat' }).ok).toBe(true);
  });
});
