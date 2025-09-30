export function getDefaultApiBase() {
  return `${window.location.protocol}//${window.location.hostname}:8000`;
}

export async function ping(base) {
  const url = `${base.replace(/\/$/, "")}/api/health`;
  const res = await fetch(url, { cache: "no-store" });
  return res.ok;
}

export function cameraFeedUrl(base) {
  return `${base.replace(/\/$/, "")}/api/camera/video_feed`;
}
