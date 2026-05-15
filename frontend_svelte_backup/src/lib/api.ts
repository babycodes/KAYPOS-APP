// KAYPOS — API Client V3 (dynamic host for WiFi access)
// Automatically uses the same hostname as the page, so it works on
// localhost, 192.168.x.x, and kaypos.local

function getApiBase(): string {
  if (typeof window === 'undefined') return 'http://localhost:3000/api';
  // Use same hostname as page, port 3000
  const host = window.location.hostname;
  return `http://${host}:3000/api`;
}

let authToken = "";

async function request<T = any>(method: string, path: string, body?: any): Promise<T> {
  const headers: Record<string, string> = { "Authorization": `Bearer ${authToken}` };
  if (body && !(body instanceof FormData)) headers["Content-Type"] = "application/json";

  const res = await fetch(`${getApiBase()}${path}`, {
    method, headers,
    body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
  });

  if (res.status === 401 && !path.includes('/auth/login') && !path.includes('/auth/verify-pin')) {
    if (typeof window !== "undefined") window.location.href = "/login";
    throw new Error("Sesi habis, silakan login kembali");
  }

  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Request failed");
  return data;
}

export const api = {
  get: <T = any>(path: string) => request<T>("GET", path),
  post: <T = any>(path: string, body?: any) => request<T>("POST", path, body),
  put: <T = any>(path: string, body?: any) => request<T>("PUT", path, body),
  del: <T = any>(path: string) => request<T>("DELETE", path),
  delete: <T = any>(path: string) => request<T>("DELETE", path),

  setToken(token: string) { authToken = token; },
  getToken() { return authToken; },

  // Backup download
  downloadBackup: async () => {
    const res = await fetch(`${getApiBase()}/backup/download`, {
      headers: { "Authorization": `Bearer ${authToken}` },
    });
    if (!res.ok) throw new Error("Download gagal");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `kaypos_backup_${new Date().toISOString().slice(0, 19).replace(/[:.]/g, "-")}.db`;
    a.click();
    URL.revokeObjectURL(url);
  },
};
