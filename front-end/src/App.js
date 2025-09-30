// src/App.js
import { useEffect, useMemo, useState } from "react";
import "./App.css";

/**
 * Base API:
 * - En prod (build servi par Flask) => même origine
 * - En dev (npm start) => définir REACT_APP_API_BASE, ex: http://192.168.4.1:8000
 */
const DEFAULT_BASE =
  process.env.REACT_APP_API_BASE || `${window.location.origin}`;

export default function App() {
  const [apiBase, setApiBase] = useState(DEFAULT_BASE);
  const feedUrl = useMemo(
    () => `${apiBase.replace(/\/$/, "")}/api/camera/video_feed`,
    [apiBase]
  );
  const healthUrl = useMemo(
    () => `${apiBase.replace(/\/$/, "")}/api/health`,
    [apiBase]
  );

  const [health, setHealth] = useState({ ok: false, last: null });
  const [imgError, setImgError] = useState(false);

  // Ping /api/health toutes les 5 s
  useEffect(() => {
    let stop = false;
    const tick = async () => {
      try {
        const res = await fetch(healthUrl, { cache: "no-store" });
        const ok = res.ok;
        if (!stop) setHealth({ ok, last: new Date().toLocaleTimeString() });
      } catch (e) {
        if (!stop) setHealth({ ok: false, last: new Date().toLocaleTimeString() });
      }
    };
    tick();
    const id = setInterval(tick, 5000);
    return () => {
      stop = true;
      clearInterval(id);
    };
  }, [healthUrl]);

  return (
    <div className="App" style={{ padding: 16, maxWidth: 960, margin: "0 auto" }}>
      <header style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
        <h1 style={{ margin: 0 }}>TSD — Caméra</h1>
        <span
          title={health.ok ? "API OK" : "API indisponible"}
          style={{
            width: 10,
            height: 10,
            borderRadius: "50%",
            background: health.ok ? "#2ecc71" : "#e74c3c",
            display: "inline-block",
          }}
        />
        <small style={{ color: "#666" }}>
          {health.last ? `Dernier check: ${health.last}` : "…"}
        </small>
      </header>

      <section
        style={{
          display: "grid",
          gap: 12,
          gridTemplateColumns: "1fr",
          alignItems: "start",
          marginBottom: 16,
        }}
      >
        <label style={{ textAlign: "left" }}>
          <div style={{ fontSize: 12, color: "#666", marginBottom: 6 }}>API Base URL</div>
          <input
            value={apiBase}
            onChange={(e) => setApiBase(e.target.value)}
            placeholder="http://192.168.4.1:8000"
            style={{
              width: "100%",
              padding: "10px 12px",
              border: "1px solid #ddd",
              borderRadius: 8,
              fontFamily: "monospace",
            }}
          />
        </label>
      </section>

      <section style={{ textAlign: "left", marginBottom: 8 }}>
        <div style={{ fontSize: 12, color: "#666" }}>Flux MJPEG</div>
        <code style={{ fontSize: 12 }}>{feedUrl}</code>
      </section>

      <div
        style={{
          width: "100%",
          background: "#111",
          borderRadius: 12,
          overflow: "hidden",
          border: "1px solid #222",
        }}
      >
        {!imgError ? (
          <img
            src={feedUrl}
            alt="Pi Camera"
            style={{ width: "100%", display: "block" }}
            onError={() => setImgError(true)}
            onLoad={() => setImgError(false)}
          />
        ) : (
          <div style={{ color: "#fff", padding: 20 }}>
            Impossible d’afficher le flux. Vérifie :
            <ul>
              <li>Que le backend Flask tourne</li>
              <li>Que l’URL est correcte</li>
              <li>Que la caméra est détectée</li>
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}
