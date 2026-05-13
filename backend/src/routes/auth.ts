// KAYPOS — Auth Routes V3 (PIN lock + password/pin change)
import { Hono } from "hono";
import db from "../db/index";
import { createSession, deleteSession, getSession } from "../middleware/auth";

const auth = new Hono();

// POST /api/auth/login
auth.post("/login", async (c) => {
  const { username, password } = await c.req.json<{ username: string; password: string }>();
  if (!username || !password) return c.json({ error: "Username dan password wajib" }, 400);
  const user = db.prepare("SELECT id, username, name, password, role FROM users WHERE username = ? AND is_active = 1").get(username) as any;
  if (!user || user.password !== password) return c.json({ error: "Username atau password salah" }, 401);
  const token = createSession(user.id, user.role, user.name);
  return c.json({ token, user: { id: user.id, username: user.username, name: user.name, role: user.role } });
});

// POST /api/auth/verify-pin — verify PIN for lock screen
auth.post("/verify-pin", async (c) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "") || "";
  const session = getSession(token);
  if (!session) return c.json({ error: "Unauthorized" }, 401);
  const { pin } = await c.req.json<{ pin: string }>();
  if (!pin) return c.json({ error: "PIN wajib diisi" }, 400);
  const user = db.prepare("SELECT pin FROM users WHERE id = ?").get(session.userId) as any;
  if (!user || user.pin !== pin) return c.json({ error: "PIN salah" }, 401);
  return c.json({ success: true });
});

// POST /api/auth/logout
auth.post("/logout", async (c) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "") || "";
  deleteSession(token);
  return c.json({ success: true });
});

// GET /api/auth/me
auth.get("/me", async (c) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "") || "";
  const session = getSession(token);
  if (!session) return c.json({ error: "Unauthorized" }, 401);
  const user = db.prepare("SELECT id, username, name, role FROM users WHERE id = ?").get(session.userId);
  return c.json(user);
});

// PUT /api/auth/profile — update name, password, or pin
auth.put("/profile", async (c) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "") || "";
  const session = getSession(token);
  if (!session) return c.json({ error: "Unauthorized" }, 401);

  const body = await c.req.json<{
    name?: string;
    old_password?: string; new_password?: string; confirm_password?: string;
    old_pin?: string; new_pin?: string; confirm_pin?: string;
  }>();

  const user = db.prepare("SELECT password, pin FROM users WHERE id = ?").get(session.userId) as any;
  if (!user) return c.json({ error: "User tidak ditemukan" }, 404);

  // Change password
  if (body.new_password) {
    if (!body.old_password) return c.json({ error: "Password lama wajib diisi" }, 400);
    if (user.password !== body.old_password) return c.json({ error: "Password lama salah" }, 400);
    if (body.new_password !== body.confirm_password) return c.json({ error: "Konfirmasi password tidak cocok" }, 400);
    if (body.new_password.length < 4) return c.json({ error: "Password minimal 4 karakter" }, 400);
    db.prepare("UPDATE users SET password = ? WHERE id = ?").run(body.new_password, session.userId);
  }

  // Change PIN
  if (body.new_pin) {
    if (!body.old_pin) return c.json({ error: "PIN lama wajib diisi" }, 400);
    if (user.pin !== body.old_pin) return c.json({ error: "PIN lama salah" }, 400);
    if (body.new_pin !== body.confirm_pin) return c.json({ error: "Konfirmasi PIN tidak cocok" }, 400);
    if (!/^\d{6}$/.test(body.new_pin)) return c.json({ error: "PIN harus 6 angka" }, 400);
    db.prepare("UPDATE users SET pin = ? WHERE id = ?").run(body.new_pin, session.userId);
  }

  // Change name
  if (body.name) {
    db.prepare("UPDATE users SET name = ? WHERE id = ?").run(body.name, session.userId);
  }

  return c.json({ success: true });
});

export default auth;
