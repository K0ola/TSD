set -euo pipefail
cd "$(dirname "$0")"

BRANCH="${BRANCH:-main}"

echo "🔄 Fetch + reset sur origin/$BRANCH"
git fetch origin
git reset --hard "origin/$BRANCH"

# Nettoyage sans toucher venv, node_modules, logs, etc.
# -e = exclude (répétable)
git clean -fd \
  -e venv \
  -e front-end/node_modules \
  -e .env \
  -e .logs \
  -e .pids

# ===== Python =====
cd server
if [ ! -d venv ]; then
  echo "🐍 Création venv…"
  python3 -m venv venv
fi
source venv/bin/activate
python -m pip install --upgrade pip

# (réinstalle seulement si requirements.txt a changé)
REQ_HASH_NEW="$(sha256sum requirements.txt 2>/dev/null | awk '{print $1}')" || REQ_HASH_NEW=""
REQ_HASH_OLD="$(cat .requirements.sha256 2>/dev/null || true)"
if [ "$REQ_HASH_NEW" != "$REQ_HASH_OLD" ]; then
  echo "📦 Maj deps Python…"
  pip install -r requirements.txt
  echo "${REQ_HASH_NEW}" > .requirements.sha256
else
  echo "📦 Deps Python déjà à jour."
fi
deactivate

# ===== Front (npm) =====
cd ../front-end
if [ ! -d node_modules ]; then
  echo "🧩 npm install (node_modules absent)…"
  if [ -f package-lock.json ]; then npm ci; else npm install; fi
else
  # réinstalle si le lockfile a changé
  LOCK_HASH_NEW="$(sha256sum package-lock.json 2>/dev/null | awk '{print $1}')" || LOCK_HASH_NEW=""
  LOCK_HASH_OLD="$(cat .package-lock.sha256 2>/dev/null || true)"
  if [ "$LOCK_HASH_NEW" != "$LOCK_HASH_OLD" ]; then
    echo "🧩 Lock modifié → npm ci…"
    npm ci
    echo "${LOCK_HASH_NEW}" > .package-lock.sha256
  else
    echo "🧩 Deps npm déjà à jour."
  fi
fi

echo "✅ Update terminé (environnements conservés)"
