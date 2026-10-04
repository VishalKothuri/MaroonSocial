import { previewPongFlight } from './engine.js';
const clamp = (value, low, high) => Math.min(high, Math.max(low, value));

// Independent horizontal/vertical screen axes make short and long pulls steer
// equally. Camera perspective never changes the direction or power sensitivity.
export function pongPull(start, end, viewport, initialAim = 0) {
  const width = Math.max(1, viewport.width), height = Math.max(1, viewport.height);
  const dx = end.x - start.x, dy = end.y - start.y;
  return {
    aim: clamp(initialAim - dx / width * .52, -.24, .24),
    power: clamp(dy / (height * .33), .03, 1),
    releases: dy >= 12,
  };
}

// Draw the real solver's approach to its first cup/rim contact. Bounce throws
// include the first table bounce; this is an aiming guide, never a scored turn.
export function pongGuide(state, input) {
  const replay = previewPongFlight(state, input);
  let bounces = 0;
  const contact = replay.events.find(event => event.type !== 'bounce' || ++bounces >= (input.bounce ? 2 : 1));
  const stop = Math.min(replay.frames.length - 1, Math.ceil(Math.min(contact?.t ?? replay.duration, 1.5) * replay.fps));
  const points = replay.frames.slice(0, stop + 1).filter((_, i) => i % 2 === 0 || i === stop);
  return { points, target: replay.frames[stop], contact: contact?.type ?? 'miss' };
}
