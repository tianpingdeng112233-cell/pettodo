import { imageGeometry, removeSolidBackground } from './background.js';
import { GeminiClient } from './gemini.js';
import { buildRigPack } from './pack.js';
import { buildRig } from './rig.js';
import type { RigPackPipeline } from './types.js';

export class GeminiRigPackPipeline implements RigPackPipeline {
  constructor(private readonly gemini: GeminiClient) {}

  async build(input: Parameters<RigPackPipeline['build']>[0]): Promise<Buffer> {
    const generated = await this.gemini.generateCanonicalImages(input.photos, input.species);
    const [frontOpen, frontClosed, sleep, side] = await Promise.all([
      removeSolidBackground(generated.frontOpen),
      removeSolidBackground(generated.frontClosed),
      removeSolidBackground(generated.sleep),
      removeSolidBackground(generated.side),
    ]);
    const [frontGeometry, frontClosedGeometry, sleepGeometry, sideGeometry] = await Promise.all([
      imageGeometry(frontOpen),
      imageGeometry(frontClosed),
      imageGeometry(sleep),
      imageGeometry(side),
    ]);
    // all four canonical sprites must have a visible subject, and the front
    // pair must share dimensions so the front boxes fit both (v3 contract)
    if (
      frontClosedGeometry.width !== frontGeometry.width ||
      frontClosedGeometry.height !== frontGeometry.height
    ) {
      throw new Error('front-open and front-closed must share dimensions');
    }
    void sleepGeometry;
    const [frontBoxes, sideBoxes] = await Promise.all([
      this.gemini.detectFrontBoxes(frontOpen, frontGeometry.width, frontGeometry.height),
      this.gemini.detectSideBoxes(side, sideGeometry.width, sideGeometry.height),
    ]);
    const rig = buildRig({
      frontGroundY: frontGeometry.groundY,
      frontBoxes,
      sideGroundY: sideGeometry.groundY,
      sideBoxes,
    });

    return buildRigPack({
      hatchId: input.hatchId,
      species: input.species,
      ...(input.petName === undefined ? {} : { petName: input.petName }),
      images: {
        'front-open.png': frontOpen,
        'front-closed.png': frontClosed,
        'sleep.png': sleep,
        'side.png': side,
      },
      rig,
    });
  }
}
