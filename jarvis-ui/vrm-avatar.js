import * as THREE from "https://unpkg.com/three@0.165.0/build/three.module.js";
import { GLTFLoader } from "https://unpkg.com/three@0.165.0/examples/jsm/loaders/GLTFLoader.js";
import { VRMLoaderPlugin, VRMUtils } from "https://unpkg.com/@pixiv/three-vrm@2.1.1/lib/three-vrm.module.min.js";

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

function setAvatarTag(text) {
  if (avatarTag) {
    avatarTag.textContent = text;
  }
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
    const vrm = gltf.userData.vrm;
    if (!vrm) {
      throw new Error("No VRM data in loaded model");
    }

    VRMUtils.removeUnnecessaryVertices(gltf.scene);
    VRMUtils.removeUnnecessaryJoints(gltf.scene);

    currentVrm = vrm;
    scene.add(vrm.scene);

    vrm.scene.rotation.y = Math.PI;
    vrm.scene.position.set(0, -1.02, 0);

    avatarCore.classList.add("vrm-ready");
    setAvatarTag("AI AVATAR: FEM_VROID ONLINE");

    onResize();
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
  }

  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

requestAnimationFrame(animate);
