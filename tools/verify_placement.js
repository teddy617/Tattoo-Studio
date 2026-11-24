// Offline smoke test for the embedded placement renderer.
// Run: node tools/verify_placement.js
// Requires no npm dependencies, network, browser or Flutter SDK.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('assets/placement/full_body.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'Bundled inline WebGL script must exist');
new vm.Script(script);
assert.ok(script.includes("atan(sideways,vec2(facingClamped))"),
  'Curved-surface angular correction must be part of the shader');
assert.ok(script.includes("uCurvature"),
  'Surface conformance must remain adjustable');

const events = [];
const handlers = {};
const uniforms = {};
let surfacePatchDraws = 0;
let nextFrame;
let elapsed = 1000;
const gl = new Proxy({}, {
  get(_target, key) {
    if (key === 'getShaderParameter' || key === 'getProgramParameter')
      return () => true;
    if (key === 'getAttribLocation') return () => 0;
    if (key === 'getUniformLocation') return (_program, name) => name;
    if (key === 'uniform1f') return (name, value) => { uniforms[name] = value; };
    if (key === 'drawElements') return () => {
      if (uniforms.uGeodesic === 1) {
        assert.equal(uniforms.uSelected, 1,
          'Surface patch must enable tattoo rendering in the shader');
        surfacePatchDraws++;
      }
    };
    if (['createShader', 'createProgram', 'createBuffer',
      'createTexture'].includes(key)) return () => ({});
    if (typeof key === 'string' && key === key.toUpperCase()) return 1;
    return () => {};
  },
});
const canvas = {
  width: 420, height: 840, clientWidth: 420, clientHeight: 840,
  getContext: () => gl,
  addEventListener(name, callback) { handlers[name] = callback; },
  setPointerCapture() {},
  getBoundingClientRect: () =>
    ({ left: 0, top: 0, width: 420, height: 840 }),
};
const status = { textContent: '' };
const bridge = {
  addEventListener() {},
  PlacementBridge: { postMessage: value => events.push(value) },
};
class MockImage {
  constructor() { this.width = 128; this.height = 256; }
  set src(_) { this.onload?.(); }
}
vm.runInNewContext(script, {
  document: { getElementById: id => id === 'view' ? canvas : status },
  window: bridge,
  requestAnimationFrame(callback) { nextFrame = callback; },
  devicePixelRatio: 1,
  Image: MockImage,
  performance: { now: () => elapsed },
}, { timeout: 15000 });

const parsed = () => events.map(value => {
  try { return JSON.parse(value); } catch { return value; }
});
assert.ok(parsed().includes('ready'), 'Viewer must signal ready');
bridge.setTattoo('data:image/png;base64,mock');
bridge.addTattoo('second', 'data:image/png;base64,mock');
bridge.selectTattoo('second');
bridge.setPlacement({ widthCm: 12, feather: .06, curvature: .8, opacity: .7 });
bridge.setMode('place');

const model = fs.readFileSync('assets/placement/models/makehuman_cc0.obj', 'utf8');
for (let index = 0; index < model.length; index += 45000) {
  bridge.appendAnatomy(model.slice(index, index + 45000));
}
bridge.finishAnatomy();
const loaded = parsed().find(value => value?.type === 'anatomyLoaded');
assert.ok(loaded && loaded.faces > 10000,
  'Detailed anatomical surface must parse and load');

bridge.selectPart('rightForearm');
elapsed = 2400;
nextFrame();
nextFrame();
assert.ok(surfacePatchDraws > 0,
  'Detailed mannequin must draw at least one skin-connected tattoo patch');
const previousPatchDraws = surfacePatchDraws;
bridge.setAnatomyMode('basic');
nextFrame();
assert.equal(surfacePatchDraws, previousPatchDraws,
  'Basic mannequin must use the older planar fallback');
bridge.setAnatomyMode('detailed');
nextFrame();
bridge.nudgeTattoo(1, 0);
bridge.resetView();
bridge.restorePlacement({
  modelVersion: 'anatomy-mainbody-v2',
  viewPart: 'full', activeId: 'second',
  tattoos: [
    { id: 'current', bodyPart: 'leftCalf', centerU: .4, centerV: .5 },
    { id: 'second', bodyPart: 'chest', centerU: .1, centerV: .5,
      feather: .06, curvature: .8, widthCm: 12, surfacePatch: true },
  ],
});
// Simulate Android tap and drag to detect removed/undefined gesture variables.
handlers.pointerdown({ pointerId: 1, clientX: 250, clientY: 350 });
handlers.pointermove({ pointerId: 1, clientX: 253, clientY: 354 });
handlers.pointerup({ pointerId: 1, clientX: 253, clientY: 354 });
const state = parsed().filter(value => value?.type === 'state').at(-1);
assert.equal(state.tattoos.length, 2);
assert.equal(state.activeId, 'second');
assert.equal(state.tattoos.find(t => t.id === 'second').feather, .06);
assert.equal(state.tattoos.find(t => t.id === 'second').curvature, .8);
assert.equal(state.tattoos.find(t => t.id === 'second').surfacePatch, true);
console.log('Placement smoke test passed: model, connected skin patch, gestures, two tattoos, restore.');
