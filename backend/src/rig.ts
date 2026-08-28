import type { Box, FrontBoxes, SideBoxes } from './gemini.js';

type Point = [number, number];

export interface ContentGeometry {
  width: number;
  height: number;
  bounds: readonly [number, number, number, number];
  topRows: readonly [number, number, number, number];
}

export interface RigJson {
  rigVersion: 1;
  front: {
    groundY: number;
    boxes: FrontBoxes;
    pivots: { head: Point | null; tail: Point };
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
        head: input.frontBoxes.head === null ? null : bottomCenter(input.frontBoxes.head),
        tail: bodySideCenter(
          input.frontBoxes.tail,
          input.frontBoxes.head ?? bodyCenter(input.frontBoxes),
        ),
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

/**
 * A nullable front head in rig.json means detection failed this gate. Clients
 * must render the complete front-open/front-closed poses instead of splitting
 * out or animating a head layer.
 */
export function isValidFrontHeadBox(
  head: Box,
  content: ContentGeometry,
): boolean {
  const [contentX0, contentY0, contentX1, contentY1] = content.bounds;
  const [topX0, topY0, topX1] = content.topRows;
  const [x0, y0, x1, y1] = head;
  const contentWidth = contentX1 - contentX0;
  const contentHeight = contentY1 - contentY0;
  const margin = Math.max(2, Math.ceil(contentWidth * 0.01));
  const intersects = x0 < contentX1 && x1 > contentX0 && y0 < contentY1 && y1 > contentY0;
  const includesFace = y1 >= contentY0 + contentHeight * 0.3;
  const wideEnough = x1 - x0 >= contentWidth * 0.35;
  const containsTopRows =
    y0 <= Math.min(content.height, topY0 + margin) &&
    x0 <= Math.min(content.width, topX0 + margin) &&
    x1 >= Math.max(0, topX1 - margin);
  return intersects && includesFace && wideEnough && containsTopRows;
}

function bottomCenter([x0, , x1, y1]: Box): Point {
  return [Math.round((x0 + x1) / 2), y1];
}

function topCenter([x0, y0, x1]: Box): Point {
  return [Math.round((x0 + x1) / 2), y0];
}

function bodyCenter(boxes: FrontBoxes): Point {
  const left = boxes.leftFrontLeg;
  const right = boxes.rightFrontLeg;
  return [
    Math.round((left[0] + left[2] + right[0] + right[2]) / 4),
    Math.round((left[1] + right[1]) / 2),
  ];
}

function bodySideCenter([x0, y0, x1, y1]: Box, bodyReference: Box | Point): Point {
  // Use the head centre when valid, or the front-leg body centre when the
  // head is absent; never use canvas centre for an off-centre sprite.
  const headCenter = bodyReference.length === 4
    ? (bodyReference[0] + bodyReference[2]) / 2
    : bodyReference[0];
  const bodySideX = Math.abs(x0 - headCenter) <= Math.abs(x1 - headCenter) ? x0 : x1;
  return [bodySideX, Math.round((y0 + y1) / 2)];
}
