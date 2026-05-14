// KAYPOS — Inventory Routes
import { Hono } from "hono";
import db from "../db/index";

const inventory = new Hono();

// GET /api/inventory — all stock with product info
inventory.get("/", (c) => {
  const rows = db.prepare(`
    SELECT i.product_id, i.stock_quantity, i.min_stock_alert, i.updated_at,
           p.name, p.is_active,
           c.name as category_name,
           (SELECT pu.unit_name FROM product_units pu WHERE pu.product_id = p.id ORDER BY pu.qty_per_unit ASC LIMIT 1) as base_unit
    FROM inventory i
    JOIN products p ON i.product_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1
    ORDER BY c.sort_order, p.name
  `).all();
  return c.json(rows);
});

// GET /api/inventory/low-stock
inventory.get("/low-stock", (c) => {
  const rows = db.prepare(`
    SELECT i.product_id, i.stock_quantity, i.min_stock_alert,
           p.name, c.name as category_name,
           (SELECT pu.unit_name FROM product_units pu WHERE pu.product_id = p.id ORDER BY pu.qty_per_unit ASC LIMIT 1) as base_unit
    FROM inventory i
    JOIN products p ON i.product_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1 AND i.stock_quantity <= i.min_stock_alert AND i.min_stock_alert > 0
    ORDER BY i.stock_quantity ASC
  `).all();
  return c.json(rows);
});

// PUT /api/inventory/:product_id — adjust stock
inventory.put("/:product_id", async (c) => {
  const productId = c.req.param("product_id");
  const { stock_quantity, min_stock_alert, adjustment } = await c.req.json<{
    stock_quantity?: number; min_stock_alert?: number; adjustment?: number;
  }>();

  if (adjustment !== undefined) {
    db.prepare("UPDATE inventory SET stock_quantity = stock_quantity + ?, updated_at = datetime('now','localtime') WHERE product_id = ?")
      .run(adjustment, productId);
  } else if (stock_quantity !== undefined) {
    db.prepare("UPDATE inventory SET stock_quantity = ?, updated_at = datetime('now','localtime') WHERE product_id = ?")
      .run(stock_quantity, productId);
  }

  if (min_stock_alert !== undefined) {
    db.prepare("UPDATE inventory SET min_stock_alert = ? WHERE product_id = ?").run(min_stock_alert, productId);
  }

  const updated = db.prepare("SELECT * FROM inventory WHERE product_id = ?").get(productId);
  return c.json(updated);
});

export default inventory;
