// KAYPOS — Users CRUD V2 (username + password)
import { Hono } from "hono";
import db from "../db/index";

const users = new Hono();

users.get("/", (c) => {
  const rows = db.prepare("SELECT id, username, name, role, is_active, created_at FROM users ORDER BY role DESC, name").all();
  return c.json(rows);
});

users.post("/", async (c) => {
  const { username, name, password, role } = await c.req.json<{ username: string; name: string; password: string; role?: string }>();
  if (!username?.trim()) return c.json({ error: "Username wajib" }, 400);
  if (!name?.trim()) return c.json({ error: "Nama wajib" }, 400);
  if (!password) return c.json({ error: "Password wajib" }, 400);
  try {
    const result = db.prepare("INSERT INTO users (username, name, password, role) VALUES (?, ?, ?, ?)")
      .run(username.trim().toLowerCase(), name.trim(), password, role || "kasir");
    return c.json({ id: result.lastInsertRowid, username, name, role: role || "kasir" }, 201);
  } catch {
    return c.json({ error: "Username sudah digunakan" }, 409);
  }
});

users.put("/:id", async (c) => {
  const id = c.req.param("id");
  const { name, password, is_active } = await c.req.json<{ name?: string; password?: string; is_active?: number }>();
  db.prepare("UPDATE users SET name=COALESCE(?,name), password=COALESCE(?,password), is_active=COALESCE(?,is_active) WHERE id=?")
    .run(name, password, is_active, id);
  return c.json({ success: true });
});

users.delete("/:id", (c) => {
  db.prepare("UPDATE users SET is_active = 0 WHERE id = ?").run(c.req.param("id"));
  return c.json({ success: true });
});

export default users;
