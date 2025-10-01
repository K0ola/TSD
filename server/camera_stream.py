# camera_stream.py
import os
from io import BytesIO
from flask import Blueprint, Response

# Essayez d'activer Picamera2 si dispo
try:
    from picamera2 import Picamera2
    PICAMERA2_AVAILABLE = True
except Exception:
    PICAMERA2_AVAILABLE = False

WIDTH  = int(os.getenv("WIDTH", "640"))
HEIGHT = int(os.getenv("HEIGHT", "480"))
FPS    = int(os.getenv("FPS", "30"))
JPEG_QUALITY = int(os.getenv("JPEG_QUALITY", "80"))

bp_camera = Blueprint("camera", __name__)

def mjpeg_generator_picamera2():
    """Flux MJPEG via Picamera2, encodage JPEG avec Pillow (pas de cv2)."""
    from PIL import Image  # import local
    import numpy as np

    picam2 = Picamera2()
    config = picam2.create_video_configuration(
        main={"size": (WIDTH, HEIGHT), "format": "RGB888"}
    )
    picam2.configure(config)
    picam2.start()
    try:
        while True:
            frame = picam2.capture_array()          # numpy RGB888 (H,W,3)
            # Encodage JPEG
            im = Image.fromarray(frame, mode="RGB")
            buf = BytesIO()
            im.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            jpeg_bytes = buf.getvalue()
            yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" +
                   jpeg_bytes + b"\r\n")
    finally:
        picam2.stop()

def mjpeg_generator_opencv():
    """Flux MJPEG via V4L2 + OpenCV (uniquement si nécessaire)."""
    import cv2  # import local, évite l’erreur si non installé
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
            ok, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY])
            if not ok:
                continue
            yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" +
                   buf.tobytes() + b"\r\n")
    finally:
        cap.release()

@bp_camera.route("/video_feed")
def video_feed():
    gen = mjpeg_generator_picamera2() if PICAMERA2_AVAILABLE else mjpeg_generator_opencv()
    return Response(gen, mimetype="multipart/x-mixed-replace; boundary=frame")
