import type { Box, FrontBoxes, SideBoxes } from './gemini.js';

type Point = [number, number];

export interface RigJson {
  rigVersion: 1;
  front: {
    groundY: number;
    boxes: FrontBoxes;
    pivots: { head: Point; tail: Point };
  };
  side: {
    groundY: number;
    facing: 'right';
    boxes: SideBoxes;
    pivots: { head: Point; tail: Point; frontLeg: Point; hindLeg: Point };
  };
}

export function buildRig(input: {
  frontGroundY: number;
  frontBoxes: FrontBoxes;
  sideGroundY: number;
  sideBoxes: SideBoxes;
}): RigJson {
  return {
    rigVersion: 1,
    front: {
      groundY: input.frontGroundY,
      boxes: input.frontBoxes,
      pivots: {
        head: bottomCenter(input.frontBoxes.head),
        tail: bodySideCenter(input.frontBoxes.tail, input.frontBoxes.head),
      },
    },
    side: {
      groundY: input.sideGroundY,
      facing: 'right',
      boxes: input.sideBoxes,
      pivots: {
        head: bottomCenter(input.sideBoxes.head),
        tail: bodySideCenter(input.sideBoxes.tail, input.sideBoxes.head),
        frontLeg: topCenter(input.sideBoxes.frontLeg),
        hindLeg: topCenter(input.sideBoxes.hindLeg),
      },
    },
  };
}

function bottomCenter([x0, , x1, y1]: Box): Point {
  return [Math.round((x0 + x1) / 2), y1];
}

function topCenter([x0, y0, x1]: Box): Point {
  return [Math.round((x0 + x1) / 2), y0];
}

function bodySideCenter([x0, y0, x1, y1]: Box, headBox: Box): Point {
  // the tail attaches on the edge nearest the body mass (head-box centre),
  // never the canvas centre — off-centre sprites must not flip the pivot
  const headCenter = (headBox[0] + headBox[2]) / 2;
  const bodySideX = Math.abs(x0 - headCenter) <= Math.abs(x1 - headCenter) ? x0 : x1;
  return [bodySideX, Math.round((y0 + y1) / 2)];
}
