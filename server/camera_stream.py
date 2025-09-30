# camera_stream.py
# - Privilégie Picamera2 (caméra CSI) si dispo
# - Fallback sur OpenCV /dev/video0 (USB)
# - Endpoints: "/" (test HTML), "/video_feed" (MJPEG)

import os
from flask import Flask, Response, render_template_string
try:
    from picamera2 import Picamera2
    PICAMERA2_AVAILABLE = True
except Exception:
    PICAMERA2_AVAILABLE = False

import cv2

APP_HOST = os.getenv("HOST", "0.0.0.0")
APP_PORT = int(os.getenv("PORT", "5000"))
WIDTH = int(os.getenv("WIDTH", "640"))
HEIGHT = int(os.getenv("HEIGHT", "480"))
FPS = int(os.getenv("FPS", "30"))
JPEG_QUALITY = int(os.getenv("JPEG_QUALITY", "80"))

app = Flask(__name__)

HTML = f"""
<!doctype html>
<title>Pi Camera</title>
<h1>Flux vidéo (MJPEG)</h1>
<p>→ <a href="/video_feed" target="_blank">/video_feed</a></p>
<p>Résolution: {WIDTH}x{HEIGHT} @ {FPS} fps — Qualité JPEG: {JPEG_QUALITY}</p>
<img src="/video_feed" style="max-width:100%; border:1px solid #ccc; border-radius:8px"/>
"""

@app.route("/")
def index():
    return render_template_string(HTML)

def mjpeg_generator_picamera2():
    picam2 = Picamera2()
    config = picam2.create_video_configuration(
        main={"size": (WIDTH, HEIGHT), "format": "RGB888"}
    )
    picam2.configure(config)
    picam2.start()

    try:
        while True:
            frame = picam2.capture_array()  # RGB ndarray
            ok, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY])
            if not ok:
                continue
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" + buf.tobytes() + b"\r\n")
    finally:
        picam2.stop()

def mjpeg_generator_opencv():
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)  # webcam USB / PiCam exposée en /dev/video0
    # Réglages souhaités (selon support du driver)
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
            ok, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY])
            if not ok:
                continue
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" + buf.tobytes() + b"\r\n")
    finally:
        cap.release()

@app.route("/video_feed")
def video_feed():
    if PICAMERA2_AVAILABLE:
        gen = mjpeg_generator_picamera2()
    else:
        gen = mjpeg_generator_opencv()
    return Response(gen, mimetype="multipart/x-mixed-replace; boundary=frame")

if __name__ == "__main__":
    app.run(host=APP_HOST, port=APP_PORT)
