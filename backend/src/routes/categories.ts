// KAYPOS — Categories CRUD V3 (unit names only, no multiplier)
import { Hono } from "hono";
import db from "../db/index";

const categories = new Hono();

categories.get("/", (c) => {
  const rows = db.prepare(`
    SELECT c.*, (SELECT COUNT(*) FROM products WHERE category_id = c.id) as product_count
    FROM categories c ORDER BY sort_order, name
  `).all() as any[];

  const allUnits = db.prepare("SELECT * FROM category_units ORDER BY sort_order, unit_name").all() as any[];
  const unitMap = new Map<number, any[]>();
  for (const u of allUnits) {
    if (!unitMap.has(u.category_id)) unitMap.set(u.category_id, []);
    unitMap.get(u.category_id)!.push(u);
  }
  for (const c of rows) c.units = unitMap.get(c.id) || [];
  return c.json(rows);
});

categories.post("/", async (c) => {
  const { name, icon, sort_order, units } = await c.req.json<{
    name: string; icon?: string; sort_order?: number;
    units?: string[]; // just names now
  }>();
  if (!name?.trim()) return c.json({ error: "Nama kategori wajib" }, 400);
  try {
    const result = db.prepare("INSERT INTO categories (name, icon, sort_order) VALUES (?, ?, ?)")
      .run(name.trim(), icon || "📦", sort_order || 0);
    const catId = result.lastInsertRowid as number;
    if (units?.length) {
      const stmt = db.prepare("INSERT INTO category_units (category_id, unit_name, sort_order) VALUES (?, ?, ?)");
      units.forEach((u, i) => stmt.run(catId, u.trim(), i + 1));
    }
    return c.json({ id: catId, name, icon: icon || "📦" }, 201);
  } catch {
    return c.json({ error: "Kategori sudah ada" }, 409);
  }
});

categories.put("/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const { name, icon, sort_order, units } = await c.req.json<{
    name?: string; icon?: string; sort_order?: number;
    units?: string[];
  }>();
  db.prepare("UPDATE categories SET name = COALESCE(?, name), icon = COALESCE(?, icon), sort_order = COALESCE(?, sort_order) WHERE id = ?")
    .run(name, icon, sort_order, id);
  if (units) {
    db.prepare("DELETE FROM category_units WHERE category_id = ?").run(id);
    const stmt = db.prepare("INSERT INTO category_units (category_id, unit_name, sort_order) VALUES (?, ?, ?)");
    units.forEach((u, i) => stmt.run(id, u.trim(), i + 1));
  }
  return c.json({ success: true });
});

categories.delete("/:id", async (c) => {
  const id = c.req.param("id");
  const force = c.req.query("force") === "1";
  const products = db.prepare("SELECT COUNT(*) as count FROM products WHERE category_id = ?").get(id) as { count: number };
  if (products.count > 0 && !force) {
    return c.json({ error: `Kategori memiliki ${products.count} produk.`, product_count: products.count }, 400);
  }
  if (products.count > 0) {
    const prodIds = db.prepare("SELECT id FROM products WHERE category_id = ?").all(id) as { id: number }[];
    for (const p of prodIds) {
      db.prepare("DELETE FROM product_units WHERE product_id = ?").run(p.id);
      db.prepare("DELETE FROM inventory WHERE product_id = ?").run(p.id);
    }
    db.prepare("DELETE FROM products WHERE category_id = ?").run(id);
  }
  db.prepare("DELETE FROM category_units WHERE category_id = ?").run(id);
  db.prepare("DELETE FROM categories WHERE id = ?").run(id);
  return c.json({ success: true });
});

export default categories;
