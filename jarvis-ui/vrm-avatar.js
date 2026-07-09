import * as THREE from "./vendor/three/three.module.js";
import { GLTFLoader } from "./vendor/three/examples/jsm/loaders/GLTFLoader.js";
import { VRMLoaderPlugin, VRMUtils } from "./vendor/three-vrm/three-vrm.module.min.js";

const canvas = document.getElementById("vrmCanvas");
const avatarCore = document.querySelector(".avatar-core");
const avatarTag = document.getElementById("avatarTag");

if (!canvas || !avatarCore) {
  throw new Error("VRM canvas or avatar container not found");
}

const scene = new THREE.Scene();
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setClearColor(0x000000, 0);

const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 30);
camera.position.set(0, 1.42, 1.25);

const keyLight = new THREE.DirectionalLight(0x93e5ff, 1.2);
keyLight.position.set(1.6, 2.2, 2.1);
scene.add(keyLight);

const fillLight = new THREE.DirectionalLight(0x5bb5ff, 0.65);
fillLight.position.set(-1.2, 1.3, 1.6);
scene.add(fillLight);

const rimLight = new THREE.DirectionalLight(0x7bf0ff, 0.45);
rimLight.position.set(0, 0.8, -1.2);
scene.add(rimLight);

scene.add(new THREE.AmbientLight(0x6ec8ff, 0.34));

let currentVrm = null;
let last = performance.now();

const scanState = {
  neck: null,
  head: null,
  leftEye: null,
  rightEye: null,
  base: new Map(),
  enabled: false
};

const tmpEuler = new THREE.Euler(0, 0, 0, "XYZ");
const tmpQuat = new THREE.Quaternion();

function setAvatarTag(text) {
  if (avatarTag) {
    avatarTag.textContent = text;
  }
}

function getHumanoidBone(humanoid, name) {
  if (!humanoid) {
    return null;
  }

  const getNormalized = typeof humanoid.getNormalizedBoneNode === "function" ? humanoid.getNormalizedBoneNode.bind(humanoid) : null;
  const getRaw = typeof humanoid.getRawBoneNode === "function" ? humanoid.getRawBoneNode.bind(humanoid) : null;

  return (getNormalized ? getNormalized(name) : null) || (getRaw ? getRaw(name) : null) || null;
}

function configureScanBones(vrm) {
  scanState.neck = getHumanoidBone(vrm.humanoid, "neck");
  scanState.head = getHumanoidBone(vrm.humanoid, "head");
  scanState.leftEye = getHumanoidBone(vrm.humanoid, "leftEye");
  scanState.rightEye = getHumanoidBone(vrm.humanoid, "rightEye");

  scanState.base.clear();
  [scanState.neck, scanState.head, scanState.leftEye, scanState.rightEye]
    .filter(Boolean)
    .forEach((node) => {
      scanState.base.set(node, node.quaternion.clone());
    });

  scanState.enabled = scanState.base.size > 0;
}

function applyBoneLook(node, yaw, pitch) {
  if (!node) {
    return;
  }

  const base = scanState.base.get(node);
  if (!base) {
    return;
  }

  tmpEuler.set(pitch, yaw, 0);
  tmpQuat.setFromEuler(tmpEuler);
  node.quaternion.copy(base).multiply(tmpQuat);
}

function applySearchingLook(now) {
  if (!scanState.enabled) {
    return;
  }

  const t = now * 0.001;
  const yaw = Math.sin(t * 0.65) * 0.22;
  const pitch = Math.sin(t * 0.31 + 1.2) * 0.055;

  // Subtle layered motion: neck follows, head leads, eyes track a bit further.
  applyBoneLook(scanState.neck, yaw * 0.3, pitch * 0.35);
  applyBoneLook(scanState.head, yaw * 0.55, pitch * 0.6);
  applyBoneLook(scanState.leftEye, yaw * 0.9, pitch * 0.8);
  applyBoneLook(scanState.rightEye, yaw * 0.9, pitch * 0.8);
}

function onResize() {
  const rect = avatarCore.getBoundingClientRect();
  if (!rect.width || !rect.height) {
    return;
  }

  renderer.setSize(rect.width, rect.height, false);
  camera.aspect = rect.width / rect.height;
  camera.updateProjectionMatrix();
}

window.addEventListener("resize", onResize);
onResize();

const loader = new GLTFLoader();
loader.register((parser) => new VRMLoaderPlugin(parser));

setAvatarTag("AI AVATAR: LOADING VRM");

loader.load(
  "assets/vrm/fem_vroid.vrm",
  (gltf) => {
    try {
      const vrm = gltf?.userData?.vrm;
      if (!vrm) {
        setAvatarTag("AI AVATAR: VRM DATA MISSING");
        return;
      }

      if (typeof VRMUtils.removeUnnecessaryVertices === "function") {
        VRMUtils.removeUnnecessaryVertices(gltf.scene);
      }
      if (typeof VRMUtils.removeUnnecessaryJoints === "function") {
        VRMUtils.removeUnnecessaryJoints(gltf.scene);
      }

      currentVrm = vrm;
      scene.add(vrm.scene);

      vrm.scene.rotation.y = Math.PI;
      vrm.scene.position.set(0, -1.02, 0);

      configureScanBones(vrm);

      avatarCore.classList.add("vrm-ready");
      setAvatarTag(scanState.enabled ? "AI AVATAR: FEM_VROID ONLINE - SCANNING" : "AI AVATAR: FEM_VROID ONLINE");

      onResize();
    } catch {
      setAvatarTag("AI AVATAR: VRM LOAD ERROR");
    }
  },
  undefined,
  () => {
    setAvatarTag("AI AVATAR: FALLBACK MODE");
  }
);

function animate(now) {
  const delta = (now - last) / 1000;
  last = now;

  if (currentVrm) {
    currentVrm.update(delta);
    currentVrm.scene.rotation.y = Math.PI + Math.sin(now * 0.00035) * 0.12;
    applySearchingLook(now);
  }

  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

requestAnimationFrame(animate);
