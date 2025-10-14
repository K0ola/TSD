# server/camera_stream.py
import os
from io import BytesIO
from flask import Blueprint, Response, request, make_response

# Which backend to use: "picamera2" | "v4l2" | "auto"
CAM_BACKEND = os.getenv("CAM_BACKEND", "auto").lower()

def _have_picamera2() -> bool:
    try:
        from picamera2 import Picamera2  # noqa: F401
        return True
    except Exception:
        return False

WIDTH  = int(os.getenv("WIDTH", "640"))
HEIGHT = int(os.getenv("HEIGHT", "480"))
FPS    = int(os.getenv("FPS", "30"))
JPEG_QUALITY = int(os.getenv("JPEG_QUALITY", "80"))

bp_camera = Blueprint("camera", __name__)

def mjpeg_generator_picamera2():
    """MJPEG from Pi camera using Picamera2 + Pillow (no OpenCV)."""
    from picamera2 import Picamera2
    from PIL import Image

    cam = Picamera2()
    cfg = cam.create_video_configuration(main={"size": (WIDTH, HEIGHT), "format": "RGB888"})
    cam.configure(cfg)
    cam.start()

    try:
        while True:
            frame = cam.capture_array()  # numpy RGB888 (H,W,3)
            buf = BytesIO()
            Image.fromarray(frame, "RGB").save(buf, "JPEG", quality=JPEG_QUALITY, optimize=True)
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" +
                   buf.getvalue() + b"\r\n")
    finally:
        cam.stop()

def mjpeg_generator_v4l2():
    """MJPEG from a USB webcam via OpenCV (requires python3-opencv)."""
    import cv2
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
    cap.set(cv2.CAP_PROP_FPS, FPS)
    if not cap.isOpened():
        raise RuntimeError("Impossible d'ouvrir /dev/video0")

    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                continue
            ok, enc = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY])
            if not ok:
                continue
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" +
                   enc.tobytes() + b"\r\n")
    finally:
        cap.release()

def _select_generator():
    # explicit choice first
    if CAM_BACKEND == "picamera2":
        if not _have_picamera2():
            raise RuntimeError("CAM_BACKEND=picamera2, mais picamera2 n'est pas importable")
        return mjpeg_generator_picamera2
    if CAM_BACKEND == "v4l2":
        return mjpeg_generator_v4l2
    # auto
    return mjpeg_generator_picamera2 if _have_picamera2() else mjpeg_generator_v4l2

@bp_camera.route("/video_feed", methods=["GET", "OPTIONS"])
def video_feed():
    # CORS preflight (dev/front séparé)
    if request.method == "OPTIONS":
        r = make_response("", 204)
        r.headers["Access-Control-Allow-Origin"] = "*"
        r.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        r.headers["Access-Control-Allow-Headers"] = "Content-Type"
        return r

    try:
        gen = _select_generator()()  # <- generator *instance*
    except Exception as e:
        # Make the error visible in browser & front console
        return Response(f"Camera backend init error: {e}\n",
                        status=500, mimetype="text/plain")

    resp = Response(gen,
                    mimetype="multipart/x-mixed-replace; boundary=frame",
                    direct_passthrough=True)
    # helpful headers for <img cross-origin>
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    resp.headers["Pragma"] = "no-cache"
    resp.headers["Expires"] = "0"
    return resp

@bp_camera.route("/health")
def health():
    return {
        "ok": True,
        "backend": CAM_BACKEND or "auto",
        "have_picamera2": _have_picamera2(),
        "w": WIDTH, "h": HEIGHT, "fps": FPS
    }
