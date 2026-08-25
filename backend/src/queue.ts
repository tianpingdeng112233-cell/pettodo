import type { HatchQueue } from './types.js';

export class InProcessHatchQueue implements HatchQueue {
  private readonly tasks: Array<() => Promise<void>> = [];
  private running = false;
  private readonly idleWaiters: Array<() => void> = [];

  enqueue(task: () => Promise<void>): void {
    this.tasks.push(task);
    void this.drain();
  }

  async waitForIdle(): Promise<void> {
    if (!this.running && this.tasks.length === 0) return;
    await new Promise<void>((resolve) => this.idleWaiters.push(resolve));
  }

  private async drain(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      let task = this.tasks.shift();
      while (task) {
        try {
          await task();
        } catch (error) {
          console.error('Unhandled hatch queue task failure', error);
        }
        task = this.tasks.shift();
      }
    } finally {
      this.running = false;
      for (const resolve of this.idleWaiters.splice(0)) resolve();
      if (this.tasks.length > 0) void this.drain();
    }
  }
}
