// src/App.jsx (ultra simple, stable)
import { useMemo, useState } from "react";
import "./App.css";

const DEFAULT_BASE = ""; // vide = même origine/proxy (zéro CORS)

export default function App() {
  const [apiBase, setApiBase] = useState(DEFAULT_BASE);
  const base = useMemo(() => (apiBase || "").replace(/\/$/, ""), [apiBase]);
  const feedUrl = `${base}/api/camera/video_feed`;

  return (
    <div className="App" style={{ padding: 16, maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ marginTop: 0 }}>TSD — Caméra</h1>

      <label style={{ display: "block", textAlign: "left", marginBottom: 12 }}>
        <div style={{ fontSize: 12, color: "#666", marginBottom: 6 }}>
          API Base URL (laisser vide = même origine)
        </div>
        <input
          value={apiBase}
          onChange={(e) => setApiBase(e.target.value)}
          placeholder="ex: http://192.168.4.1:8000"
          style={{ width: "100%", padding: "10px 12px", border: "1px solid #ddd", borderRadius: 8, fontFamily: "monospace" }}
        />
      </label>

      <code style={{ fontSize: 12, display: "block", textAlign: "left", marginBottom: 8 }}>
        {feedUrl}
      </code>

      <div style={{ background: "#111", border: "1px solid #222", borderRadius: 12, overflow: "hidden" }}>
        <img
          src={feedUrl}
          alt="Pi Camera"
          style={{ width: "100%", display: "block" }}
        />
      </div>
    </div>
  );
}
