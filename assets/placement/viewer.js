import * as THREE from 'three';
import { OrbitControls } from './vendor/OrbitControls.js';
import { DecalGeometry } from './vendor/DecalGeometry.js';

const status = document.getElementById('status');
const send = (message) => {
  if (window.PlacementBridge) PlacementBridge.postMessage(message);
};
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x202127);
const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100);
camera.position.set(0.2, 0.25, 5.5);
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
document.body.insertBefore(renderer.domElement, status);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.minDistance = 2;
controls.maxDistance = 9;
controls.target.set(0, 0, 0);
scene.add(new THREE.HemisphereLight(0xffffff, 0x463d42, 2.2));
const keyLight = new THREE.DirectionalLight(0xffffff, 2.0);
keyLight.position.set(3, 4, 5);
scene.add(keyLight);

// Prototype forearm: 26 cm long, tapered 9.5–12 cm in diameter.
const forearm = new THREE.Mesh(
  new THREE.CylinderGeometry(0.60, 0.47, 2.6, 80, 40, false),
  new THREE.MeshStandardMaterial({
    color: 0xb98974, roughness: 0.86, metalness: 0,
    side: THREE.FrontSide
  })
);
scene.add(forearm);

const raycaster = new THREE.Raycaster();
const cursor = new THREE.Vector2();
let mode = 'orbit';
let tattooTexture = null;
let decal = null;
let point = new THREE.Vector3(0, 0, 0.53);
let normal = new THREE.Vector3(0, 0, 1);
let placement = { opacity: 0.9, scale: 0.65, rotation: 0, depth: 0.6 };
let down = null;

function updateDecal() {
  if (decal) {
    scene.remove(decal);
    decal.geometry.dispose();
    decal.material.dispose();
    decal = null;
  }
  if (!tattooTexture) return;
  const face = new THREE.Quaternion()
    .setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal.clone().normalize());
  const turn = new THREE.Quaternion()
    .setFromAxisAngle(new THREE.Vector3(0, 0, 1),
      THREE.MathUtils.degToRad(placement.rotation));
  face.multiply(turn);
  const angles = new THREE.Euler().setFromQuaternion(face);
  const width = THREE.MathUtils.clamp(placement.scale, 0.15, 1.4);
  const image = tattooTexture.image;
  const ratio = image && image.width && image.height
    ? image.height / image.width : 1;
  const geometry = new DecalGeometry(
    forearm, point, angles,
    new THREE.Vector3(width, width * ratio,
      THREE.MathUtils.clamp(placement.depth, 0.15, 1.2))
  );
  const material = new THREE.MeshBasicMaterial({
    map: tattooTexture,
    transparent: true,
    opacity: placement.opacity,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
  decal = new THREE.Mesh(geometry, material);
  scene.add(decal);
}

window.setTattoo = (uri) => {
  new THREE.TextureLoader().load(uri, texture => {
    if (tattooTexture) tattooTexture.dispose();
    tattooTexture = texture;
    tattooTexture.colorSpace = THREE.SRGBColorSpace;
    updateDecal();
    status.textContent = 'Tattoo anchored to 3D forearm surface';
  }, undefined, error => {
    send('Texture load failed');
  });
};
window.setPlacement = (raw) => {
  const values = typeof raw === 'string' ? JSON.parse(raw) : raw;
  placement = { ...placement, ...values };
  updateDecal();
};
window.setMode = (next) => {
  mode = next === 'place' ? 'place' : 'orbit';
  controls.enabled = mode === 'orbit';
  status.textContent = mode === 'place'
    ? 'Tap the forearm to place tattoo onto the surface'
    : 'Drag to rotate • Pinch to zoom';
};
window.resetPlacement = () => {
  point.set(0, 0, 0.53);
  normal.set(0, 0, 1);
  updateDecal();
};
function pointerPosition(event) {
  const bounds = renderer.domElement.getBoundingClientRect();
  cursor.x = ((event.clientX - bounds.left) / bounds.width) * 2 - 1;
  cursor.y = -((event.clientY - bounds.top) / bounds.height) * 2 + 1;
}
renderer.domElement.addEventListener('pointerdown', event => {
  down = { id: event.pointerId, x: event.clientX, y: event.clientY };
});
renderer.domElement.addEventListener('pointerup', event => {
  if (!down || down.id !== event.pointerId) return;
  const moved = Math.hypot(event.clientX - down.x, event.clientY - down.y);
  down = null;
  if (mode !== 'place' || moved > 12) return;
  pointerPosition(event);
  raycaster.setFromCamera(cursor, camera);
  const hit = raycaster.intersectObject(forearm, false)[0];
  if (!hit || !hit.face) return;
  point.copy(hit.point);
  normal.copy(hit.face.normal).transformDirection(forearm.matrixWorld);
  updateDecal();
  send('placed');
});
function frame() {
  const w = Math.max(1, window.innerWidth);
  const h = Math.max(1, window.innerHeight);
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  controls.update();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}
try {
  frame();
  send('ready');
} catch (error) {
  send('Viewer error: ' + error.message);
}
