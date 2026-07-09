import * as THREE from "./vendor/three/three.module.js";
import { GLTFLoader } from "./vendor/three/examples/jsm/loaders/GLTFLoader.js";
import { VRMLoaderPlugin } from "./vendor/three-vrm/three-vrm.module.min.js";

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
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;

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
scene.add(new THREE.HemisphereLight(0x9ce8ff, 0x081525, 0.75));

let currentVrm = null;
let currentRoot = null;
let last = performance.now();
const expressionState = {
  enabled: false
};

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
const tmpBox = new THREE.Box3();
const tmpSize = new THREE.Vector3();
const tmpCenter = new THREE.Vector3();

function frameVrm(root) {
  if (!root) {
    return false;
  }

  if (!root.scale || root.scale.x === 0 || root.scale.y === 0 || root.scale.z === 0) {
    root.scale.set(1, 1, 1);
  }

  tmpBox.setFromObject(root);
  if (tmpBox.isEmpty()) {
    return false;
  }

  tmpBox.getSize(tmpSize);
  tmpBox.getCenter(tmpCenter);

  const modelHeight = Math.max(tmpSize.y, 1e-4);
  const targetHeight = 1.2;
  const normalizeScale = THREE.MathUtils.clamp(targetHeight / modelHeight, 0.05, 30);
  root.scale.multiplyScalar(normalizeScale);

  tmpBox.setFromObject(root);
  if (tmpBox.isEmpty()) {
    return false;
  }
  tmpBox.getSize(tmpSize);
  tmpBox.getCenter(tmpCenter);

  // Normalize model origin so camera framing is reliable across different VRM exports.
  root.position.sub(tmpCenter);
  const headY = Math.max(tmpSize.y * 0.84, 0.74);
  const fovRad = (camera.fov * Math.PI) / 180;
  const distance = (tmpSize.y * 0.5) / Math.tan(fovRad * 0.5);

  camera.near = 0.01;
  camera.far = 100;
  camera.position.set(0, headY, Math.max(distance * 0.78, 0.78));
  camera.lookAt(0, headY + 0.02, 0);
  camera.updateProjectionMatrix();
  return true;
}

function expressionNameCandidates(name) {
  const firstUpper = name.charAt(0).toUpperCase() + name.slice(1);
  const upper = name.toUpperCase();
  const map = {
    aa: ["a", "A", "Aa", "AA"],
    ih: ["i", "I", "Ih", "IH"],
    ou: ["o", "O", "Ou", "OU"],
    joy: ["happy", "Happy", "JOY", "Joy"],
    blink: ["Blink_L", "Blink_R", "BLINK"]
  };

  return [name, name.toLowerCase(), firstUpper, upper, ...(map[name] || [])];
}

function setExpressionValue(vrm, name, value) {
  const v = THREE.MathUtils.clamp(value, 0, 1);
  let applied = false;

  const manager = vrm?.expressionManager;
  if (manager && typeof manager.setValue === "function") {
    expressionNameCandidates(name).forEach((candidate) => {
      try {
        manager.setValue(candidate, v);
        applied = true;
      } catch {
        // Ignore unsupported expression names.
      }
    });
  }

  const proxy = vrm?.blendShapeProxy;
  if (proxy && typeof proxy.setValue === "function") {
    expressionNameCandidates(name).forEach((candidate) => {
      try {
        proxy.setValue(candidate, v);
        applied = true;
      } catch {
        // Ignore unsupported blendshape names.
      }
    });
  }

  return applied;
}

function applyFacialExpressions(vrm, now) {
  if (!vrm) {
    return;
  }

  const t = now * 0.001;
  const blinkPulse = Math.max(0, Math.sin(t * 4.2) * 2.2 - 1.15);
  const blink = THREE.MathUtils.clamp(blinkPulse, 0, 1);
  const smile = 0.14 + Math.max(0, Math.sin(t * 0.42 + 0.4)) * 0.22;
  const mouth = Math.max(0, Math.sin(t * 2.25 + 1.1)) * 0.34;
  const mouthWide = Math.max(0, Math.sin(t * 1.6 + 2.2)) * 0.2;

  const okBlink = setExpressionValue(vrm, "blink", blink);
  const okJoy = setExpressionValue(vrm, "joy", smile);
  const okAa = setExpressionValue(vrm, "aa", mouth);
  const okIh = setExpressionValue(vrm, "ih", mouthWide);
  const okOu = setExpressionValue(vrm, "ou", mouth * 0.45);

  expressionState.enabled = okBlink || okJoy || okAa || okIh || okOu;
}

function countRenderableMeshes(root) {
  let count = 0;
  root.traverse((node) => {
    if (count > 0) {
      return;
    }
    if (!node || !node.isMesh || !node.geometry) {
      return;
    }
    const pos = node.geometry.getAttribute?.("position");
    if (pos && pos.count > 0) {
      count += 1;
    }
  });
  return count;
}

function forceMeshVisibility(root) {
  root.traverse((node) => {
    if (!node || !node.isMesh) {
      return;
    }

    node.visible = true;
    node.frustumCulled = false;
    node.layers.set(0);

    const materials = Array.isArray(node.material) ? node.material : [node.material];
    materials.filter(Boolean).forEach((mat) => {
      mat.visible = true;
      mat.transparent = false;
      mat.opacity = 1;
      mat.depthWrite = true;
      mat.side = THREE.DoubleSide;
      mat.needsUpdate = true;
    });
  });
}

function applyMaterialCompatibilityFallback(root) {
  root.traverse((node) => {
    if (!node || !node.isMesh) {
      return;
    }

    const convert = (mat) => {
      if (!mat) {
        return mat;
      }
      const looksLikeCustomShader = mat.isShaderMaterial || /mtoon|shader/i.test(mat.type || "");
      if (!looksLikeCustomShader) {
        return mat;
      }

      const fallback = new THREE.MeshStandardMaterial({
        color: 0xf4f8ff,
        map: mat.map || null,
        emissive: new THREE.Color(0x1a2433),
        emissiveIntensity: 0.2,
        roughness: 0.72,
        metalness: 0.04,
        side: THREE.DoubleSide,
        transparent: false,
        opacity: 1
      });

      fallback.skinning = !!node.isSkinnedMesh;
      fallback.morphTargets = !!node.morphTargetInfluences;
      fallback.morphNormals = !!node.morphTargetInfluences;
      return fallback;
    };

    node.material = Array.isArray(node.material) ? node.material.map(convert) : convert(node.material);
  });
}

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
  "assets/vrm/fem_vroid.vrm?v=20260709a",
  (gltf) => {
    try {
      const vrm = gltf?.userData?.vrm;
      if (!vrm) {
        setAvatarTag("AI AVATAR: VRM DATA MISSING");
        return;
      }

      currentVrm = vrm;
      currentRoot = vrm.scene && vrm.scene.children.length > 0 ? vrm.scene : gltf.scene;

      if (countRenderableMeshes(currentRoot) === 0) {
        setAvatarTag("AI AVATAR: VRM EMPTY MESH");
        avatarCore.classList.remove("vrm-ready");
        return;
      }

      forceMeshVisibility(currentRoot);
      applyMaterialCompatibilityFallback(currentRoot);

      scene.add(currentRoot);

      // Some VRM exports already face forward; forcing PI can hide the face (backface culling).
      currentRoot.rotation.y = 0;
      if (!frameVrm(currentRoot)) {
        setAvatarTag("AI AVATAR: VRM FRAME ERROR");
        avatarCore.classList.remove("vrm-ready");
        return;
      }

      configureScanBones(vrm);
      applyFacialExpressions(vrm, performance.now());

      avatarCore.classList.add("vrm-ready");
      if (scanState.enabled && expressionState.enabled) {
        setAvatarTag("AI AVATAR: FEM_VROID ONLINE - EXPRESSIVE");
      } else if (scanState.enabled) {
        setAvatarTag("AI AVATAR: FEM_VROID ONLINE - SCANNING");
      } else {
        setAvatarTag("AI AVATAR: FEM_VROID ONLINE");
      }

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
    if (currentRoot) {
      currentRoot.rotation.y = Math.sin(now * 0.00035) * 0.12;
    }
    applySearchingLook(now);
    applyFacialExpressions(currentVrm, now);
  }

  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

requestAnimationFrame(animate);
