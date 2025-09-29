# app.py
from __future__ import annotations

import os
import logging
from pathlib import Path
from datetime import datetime
from flask import Flask, send_from_directory, jsonify

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
FRONT_BUILD_DIR = (BASE_DIR / ".." / "front-end" / "build").resolve()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
DEBUG = os.getenv("DEBUG", "0") in {"1", "true", "True"}

# -----------------------------------------------------------------------------
# Logging (propre et lisible)
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
log = logging.getLogger("app")

# -----------------------------------------------------------------------------
# App
# -----------------------------------------------------------------------------
def create_app() -> Flask:
    app = Flask(
        __name__,
        static_folder=str(FRONT_BUILD_DIR),
        static_url_path="/",  # sert les fichiers statiques à la racine
    )

    # ---------------- API minimaliste ----------------
    @app.get("/api/health")
    def api_health():
        return jsonify(
            status="ok",
            time=datetime.utcnow().isoformat() + "Z",
            app="TSD_Project",
            version=os.getenv("APP_VERSION", "0.1.0"),
        )

    @app.get("/api/info")
    def api_info():
        return jsonify(
            python_version=os.sys.version.split()[0],
            flask_version=Flask.__version__,
            env="debug" if DEBUG else "production",
        )

    # ---------------- Front React (build) ----------------
    # Si le fichier demandé existe dans le build, on le renvoie.
    # Sinon, on renvoie index.html (fallback React Router).
    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def serve_react(path: str):
        # Sécurité : empêcher de sortir du répertoire
        safe_path = Path(path).as_posix()
        candidate = FRONT_BUILD_DIR / safe_path

        if path and candidate.exists() and candidate.is_file():
            return send_from_directory(FRONT_BUILD_DIR, safe_path)

        index_file = FRONT_BUILD_DIR / "index.html"
        if not index_file.exists():
            log.error(
                "Le build React est introuvable. Lance d'abord 'yarn build' "
                "dans front-end/ (ou npm run build)."
            )
            return (
                "Le build React est introuvable. "
                "Exécute 'yarn build' (ou 'npm run build') dans front-end/.",
                500,
            )
        return send_from_directory(FRONT_BUILD_DIR, "index.html")

    return app


app = create_app()

# -----------------------------------------------------------------------------
# Entrée
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    log.info(f"Démarrage serveur sur http://{HOST}:{PORT}")
    if not FRONT_BUILD_DIR.exists():
        log.warning(
            f"Le dossier build du front n'existe pas : {FRONT_BUILD_DIR}\n"
            "→ Va dans front-end/ et lance 'yarn build' ou 'npm run build'."
        )
    app.run(host=HOST, port=PORT, debug=DEBUG)
