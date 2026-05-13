// KAYPOS — Products CRUD V3 (qty_per_unit model)
import { Hono } from "hono";
import db from "../db/index";

const products = new Hono();

function getFullProduct(id: number) {
  const product = db.prepare(`
    SELECT p.*, c.name as category_name, c.icon as category_icon,
           COALESCE(i.stock_quantity, 0) as stock_quantity,
           COALESCE(i.min_stock_alert, 0) as min_stock_alert
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN inventory i ON p.id = i.product_id
    WHERE p.id = ?
  `).get(id) as any;
  if (!product) return null;
  product.units = db.prepare("SELECT * FROM product_units WHERE product_id = ? ORDER BY qty_per_unit").all(id);
  return product;
}

// GET /api/products — active with units
products.get("/", (c) => {
  const rows = db.prepare(`
    SELECT p.*, c.name as category_name, c.icon as category_icon,
           COALESCE(i.stock_quantity, 0) as stock_quantity
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN inventory i ON p.id = i.product_id
    WHERE p.is_active = 1
    ORDER BY c.sort_order, p.name
  `).all() as any[];
  const units = db.prepare("SELECT * FROM product_units ORDER BY qty_per_unit").all() as any[];
  const unitMap = new Map<number, any[]>();
  for (const u of units) {
    if (!unitMap.has(u.product_id)) unitMap.set(u.product_id, []);
    unitMap.get(u.product_id)!.push(u);
  }
  for (const p of rows) p.units = unitMap.get(p.id) || [];
  return c.json(rows);
});

// GET /api/products/all — admin
products.get("/all", (c) => {
  const rows = db.prepare(`
    SELECT p.*, c.name as category_name, c.icon as category_icon,
           COALESCE(i.stock_quantity, 0) as stock_quantity
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN inventory i ON p.id = i.product_id
    ORDER BY p.is_active DESC, c.sort_order, p.name
  `).all() as any[];
  const units = db.prepare("SELECT * FROM product_units ORDER BY qty_per_unit").all() as any[];
  const unitMap = new Map<number, any[]>();
  for (const u of units) {
    if (!unitMap.has(u.product_id)) unitMap.set(u.product_id, []);
    unitMap.get(u.product_id)!.push(u);
  }
  for (const p of rows) p.units = unitMap.get(p.id) || [];
  return c.json(rows);
});

products.get("/:id", (c) => {
  const product = getFullProduct(Number(c.req.param("id")));
  if (!product) return c.json({ error: "Produk tidak ditemukan" }, 404);
  return c.json(product);
});

products.get("/barcode/:code", (c) => {
  const row = db.prepare("SELECT id FROM products WHERE barcode = ? AND is_active = 1").get(c.req.param("code")) as { id: number } | null;
  if (!row) return c.json({ error: "Barcode tidak ditemukan" }, 404);
  return c.json(getFullProduct(row.id));
});

// POST /api/products
products.post("/", async (c) => {
  const body = await c.req.json<{
    name: string; category_id: number; barcode?: string;
    stock?: number; min_stock?: number;
    unit_prices: { unit_name: string; qty_per_unit: number; price: number }[];
  }>();
  if (!body.name?.trim()) return c.json({ error: "Nama produk wajib" }, 400);
  if (!body.unit_prices?.length) return c.json({ error: "Minimal 1 harga unit wajib" }, 400);
  try {
    const result = db.prepare("INSERT INTO products (name, category_id, barcode) VALUES (?, ?, ?)")
      .run(body.name.trim(), body.category_id, body.barcode || null);
    const productId = result.lastInsertRowid as number;
    const stmt = db.prepare("INSERT INTO product_units (product_id, unit_name, qty_per_unit, price) VALUES (?, ?, ?, ?)");
    for (const u of body.unit_prices) {
      if (u.price > 0) stmt.run(productId, u.unit_name, u.qty_per_unit || 1, u.price);
    }
    db.prepare("INSERT INTO inventory (product_id, stock_quantity, min_stock_alert) VALUES (?, ?, ?)")
      .run(productId, body.stock || 0, body.min_stock || 0);
    return c.json(getFullProduct(productId), 201);
  } catch (e: any) {
    return c.json({ error: e.message || "Gagal membuat produk" }, 400);
  }
});

// PUT /api/products/:id
products.put("/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json<{
    name?: string; category_id?: number; barcode?: string; is_active?: number;
    unit_prices?: { unit_name: string; qty_per_unit: number; price: number }[];
  }>();
  db.prepare(`UPDATE products SET
    name = COALESCE(?, name), category_id = COALESCE(?, category_id),
    barcode = COALESCE(?, barcode), is_active = COALESCE(?, is_active),
    updated_at = datetime('now','localtime') WHERE id = ?`)
    .run(body.name, body.category_id, body.barcode, body.is_active, id);
  if (body.unit_prices) {
    db.prepare("DELETE FROM product_units WHERE product_id = ?").run(id);
    const stmt = db.prepare("INSERT INTO product_units (product_id, unit_name, qty_per_unit, price) VALUES (?, ?, ?, ?)");
    for (const u of body.unit_prices) {
      if (u.price > 0) stmt.run(id, u.unit_name, u.qty_per_unit || 1, u.price);
    }
  }
  return c.json(getFullProduct(id));
});

// DELETE /api/products/:id — hard delete
products.delete("/:id", (c) => {
  const id = c.req.param("id");
  db.prepare("DELETE FROM product_units WHERE product_id = ?").run(id);
  db.prepare("DELETE FROM inventory WHERE product_id = ?").run(id);
  db.prepare("DELETE FROM products WHERE id = ?").run(id);
  return c.json({ success: true });
});

export default products;
