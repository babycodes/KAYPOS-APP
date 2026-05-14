// KAYPOS — Held Carts API (shared park system)
import { Hono } from "hono";
import db from "../db/index";
import { getSession } from "../middleware/auth";

const heldCarts = new Hono();

// GET /api/held-carts — list all held carts
heldCarts.get("/", (c) => {
  const rows = db.prepare("SELECT * FROM held_carts ORDER BY created_at ASC").all();
  return c.json(rows.map((r: any) => ({ ...r, cart_data: JSON.parse(r.cart_data) })));
});

// POST /api/held-carts — create a held cart
heldCarts.post("/", async (c) => {
  // Support token from query param (sendBeacon on page unload) or Authorization header
  const token = c.req.query("token") || c.req.header("Authorization")?.replace("Bearer ", "") || "";
  const session = getSession(token);
  const { label, cart_data, total } = await c.req.json<{ label: string; cart_data: any[]; total: number }>();
  if (!label || !cart_data || cart_data.length === 0) return c.json({ error: "Data tidak lengkap" }, 400);

  const count = (db.prepare("SELECT COUNT(*) as count FROM held_carts").get() as any).count;
  if (count >= 10) return c.json({ error: "Maksimal 10 transaksi ditahan" }, 400);

  const result = db.prepare(
    "INSERT INTO held_carts (label, cart_data, total, created_by, created_by_name) VALUES (?, ?, ?, ?, ?)"
  ).run(label, JSON.stringify(cart_data), total, session?.userId || null, session?.name || 'Unknown');

  return c.json({ id: result.lastInsertRowid, success: true });
});

// DELETE /api/held-carts/:id — remove a held cart (recalled or cancelled)
heldCarts.delete("/:id", (c) => {
  const id = c.req.param("id");
  db.prepare("DELETE FROM held_carts WHERE id = ?").run(id);
  return c.json({ success: true });
});

export default heldCarts;
