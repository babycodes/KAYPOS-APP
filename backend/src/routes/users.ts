// KAYPOS — Users CRUD V3 (simplified add + reset + delete)
import { Hono } from "hono";
import db from "../db/index";

const users = new Hono();

users.get("/", (c) => {
  const rows = db.prepare("SELECT id, username, name, role, is_active, created_at FROM users ORDER BY role DESC, name").all();
  return c.json(rows);
});

// Create user — only username + name required, default pw=pwkasir, pin=000000
users.post("/", async (c) => {
  const { username, name, role } = await c.req.json<{ username: string; name: string; role?: string }>();
  if (!username?.trim()) return c.json({ error: "Username wajib" }, 400);
  if (!name?.trim()) return c.json({ error: "Nama wajib" }, 400);
  try {
    const result = db.prepare("INSERT INTO users (username, name, password, pin, role) VALUES (?, ?, ?, ?, ?)")
      .run(username.trim().toLowerCase(), name.trim(), "pwkasir", "000000", role || "kasir");
    return c.json({ id: result.lastInsertRowid, username, name, role: role || "kasir" }, 201);
  } catch {
    return c.json({ error: "Username sudah digunakan" }, 409);
  }
});

users.put("/:id", async (c) => {
  const id = c.req.param("id");
  const { name, password, pin, is_active } = await c.req.json<{ name?: string; password?: string; pin?: string; is_active?: number }>();
  db.prepare("UPDATE users SET name=COALESCE(?,name), password=COALESCE(?,password), pin=COALESCE(?,pin), is_active=COALESCE(?,is_active) WHERE id=?")
    .run(name, password, pin, is_active, id);
  return c.json({ success: true });
});

// Reset password + PIN to defaults
users.post("/:id/reset", (c) => {
  const id = c.req.param("id");
  db.prepare("UPDATE users SET password = 'pwkasir', pin = '000000' WHERE id = ?").run(id);
  return c.json({ success: true, message: "Password & PIN berhasil direset" });
});

// Delete user permanently (except admin)
users.delete("/:id", (c) => {
  const id = c.req.param("id");
  const user = db.prepare("SELECT role FROM users WHERE id = ?").get(id) as any;
  if (!user) return c.json({ error: "User tidak ditemukan" }, 404);
  if (user.role === "admin") return c.json({ error: "Tidak bisa menghapus admin" }, 403);
  db.prepare("DELETE FROM users WHERE id = ?").run(id);
  return c.json({ success: true });
});

export default users;
