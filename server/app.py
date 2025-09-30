# app.py
from __future__ import annotations
import os, logging
from pathlib import Path
from datetime import datetime
from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from camera_stream import bp_camera

BASE_DIR = Path(__file__).resolve().parent
FRONT_BUILD_DIR = (BASE_DIR / ".." / "front-end" / "build").resolve()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
DEBUG = os.getenv("DEBUG", "0") in {"1", "true", "True"}

logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
log = logging.getLogger("app")

def create_app() -> Flask:
    app = Flask(
        __name__,
        static_folder=str(FRONT_BUILD_DIR),
        static_url_path="/",
    )

    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # -------- API minimal --------
    @app.get("/api/health")
    def api_health():
        return jsonify(status="ok", time=datetime.utcnow().isoformat() + "Z")

    @app.get("/api/info")
    def api_info():
        import flask
        return jsonify(
            python_version=os.sys.version.split()[0],
            flask_version=flask.__version__,
            env="debug" if DEBUG else "production",
        )

    # -------- Camera --------
    app.register_blueprint(bp_camera, url_prefix="/api/camera")
    # → ton flux sera accessible sur /api/camera/video_feed

    # -------- Front React --------
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_react(path: str):
        candidate = FRONT_BUILD_DIR / path
        if path and candidate.exists() and candidate.is_file():
            return send_from_directory(FRONT_BUILD_DIR, path)
        return send_from_directory(FRONT_BUILD_DIR, "index.html")

    return app

app = create_app()

if __name__ == "__main__":
    log.info(f"🚀 Serveur sur http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=DEBUG)
