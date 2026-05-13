// KAYPOS — Auth Middleware
import type { Context, Next } from "hono";

// Simple session store (in-memory, fine for local STB)
const sessions = new Map<string, { userId: number; role: string; name: string }>();

export function createSession(userId: number, role: string, name: string): string {
  const token = crypto.randomUUID();
  sessions.set(token, { userId, role, name });
  return token;
}

export function getSession(token: string) {
  return sessions.get(token) || null;
}

export function deleteSession(token: string) {
  sessions.delete(token);
}

// Middleware: require auth
export async function requireAuth(c: Context, next: Next) {
  const token = c.req.header("Authorization")?.replace("Bearer ", "") || "";
  const session = getSession(token);
  if (!session) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  c.set("user", session);
  c.set("token", token);
  await next();
}

// Middleware: require admin role
export async function requireAdmin(c: Context, next: Next) {
  const user = c.get("user") as { role: string } | undefined;
  if (!user || user.role !== "admin") {
    return c.json({ error: "Forbidden: Admin only" }, 403);
  }
  await next();
}
