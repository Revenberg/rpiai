console.log("[CAMERA] geladen");

const localBtn = document.getElementById("cameraSourceLocal");
const rpiBtn = document.getElementById("cameraSourceRpi");

const state = document.getElementById("cameraState");
const container = document.querySelector(".camera-container");

let localStream = null;


function log(msg, data) {
    console.log("[CAMERA]", msg, data || "");
}


function setState(text) {
    log("STATUS:", text);

    if (state) {
        state.textContent = text;
    }
}


function stopLocal() {

    log("stop local");

    if (localStream) {

        localStream.getTracks().forEach(track => {
            track.stop();
        });

        localStream = null;
    }
}



async function selectLocalCamera() {

    log("LOCAL geselecteerd");

    rpiBtn.classList.remove("active");
    localBtn.classList.add("active");

    stopLocal();


    container.innerHTML = `
        <video
            id="cameraVideo"
            class="camera-image"
            autoplay
            muted
            playsinline>
        </video>
    `;


    const video = document.getElementById("cameraVideo");


    try {

        log("vraag webcam");

        localStream = await navigator.mediaDevices.getUserMedia({
            video: true,
            audio: false
        });


        video.srcObject = localStream;

        setState("LOCAL");


        video.onloadedmetadata = () => {
            log("local video gestart");
            video.play();
        };


    } catch(error) {

        console.error("[CAMERA] local fout", error);

        setState("LOCAL OFFLINE");
    }
}



function selectRpiCamera() {

    log("RPI geselecteerd");


    localBtn.classList.remove("active");
    rpiBtn.classList.add("active");


    stopLocal();


    container.innerHTML = `
        <img
            id="cameraVideo"
            class="camera-image"
            src="/camera/api/stream.mjpeg?src=usb"
            alt="RPI camera">
    `;


    const img = document.getElementById("cameraVideo");


    img.onload = () => {

        log("RPI beeld ontvangen");

        setState("RPI LIVE");
    };


    img.onerror = (e) => {

        console.error("[CAMERA] RPI fout", e);

        setState("RPI OFFLINE");
    };


    setState("RPI VERBINDEN");
}



localBtn.onclick = selectLocalCamera;
rpiBtn.onclick = selectRpiCamera;


// standaard RPI
selectRpiCamera();