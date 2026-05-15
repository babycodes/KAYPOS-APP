// KAYPOS — Products CRUD V3 (qty_per_unit model)
import { Hono } from "hono";
import db from "../db/index";
import * as XLSX from "xlsx";

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
    purchase_price?: number; purchase_unit?: string;
    stock?: number; min_stock?: number;
    unit_prices: { unit_name: string; qty_per_unit: number; price: number }[];
  }>();
  if (!body.name?.trim()) return c.json({ error: "Nama produk wajib" }, 400);
  if (!body.unit_prices?.length) return c.json({ error: "Minimal 1 harga unit wajib" }, 400);
  try {
    const result = db.prepare("INSERT INTO products (name, category_id, barcode, purchase_price, purchase_unit) VALUES (?, ?, ?, ?, ?)")
      .run(body.name.trim(), body.category_id, body.barcode || null, body.purchase_price || 0, body.purchase_unit || '');
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
    purchase_price?: number; purchase_unit?: string;
    unit_prices?: { unit_name: string; qty_per_unit: number; price: number }[];
  }>();
  db.prepare(`UPDATE products SET
    name = COALESCE(?, name), category_id = COALESCE(?, category_id),
    barcode = COALESCE(?, barcode), is_active = COALESCE(?, is_active),
    purchase_price = COALESCE(?, purchase_price), purchase_unit = COALESCE(?, purchase_unit),
    updated_at = datetime('now','localtime') WHERE id = ?`)
    .run(body.name, body.category_id, body.barcode, body.is_active, body.purchase_price, body.purchase_unit, id);
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
// GET /api/products/template/excel
products.get("/template/excel", async (c) => {
  const wb = XLSX.utils.book_new();
  const headers = [
    "Barcode", "Nama Produk", "Kategori", "Stok", "Min Stok", 
    "Harga Modal", "Satuan Modal", 
    "Satuan 1", "Isi Satuan 1", "Harga Jual 1",
    "Satuan 2", "Isi Satuan 2", "Harga Jual 2",
    "Satuan 3", "Isi Satuan 3", "Harga Jual 3"
  ];
  
  const sampleData = [
    ["899123456789", "Plastik Wrap Kiloan", "Plastik", 100, 10, 100000, "kilo", "kilo", 1, 100000, "gram", 100, 10000, "", "", ""]
  ];
  
  const ws = XLSX.utils.aoa_to_sheet([headers, ...sampleData]);
  
  // Set column widths
  ws['!cols'] = [
    {wch: 15}, {wch: 30}, {wch: 15}, {wch: 10}, {wch: 10},
    {wch: 15}, {wch: 15},
    {wch: 15}, {wch: 15}, {wch: 15},
    {wch: 15}, {wch: 15}, {wch: 15},
    {wch: 15}, {wch: 15}, {wch: 15}
  ];

  XLSX.utils.book_append_sheet(wb, ws, "Template_Produk");
  
  const buffer = XLSX.write(wb, { type: "buffer", bookType: "xlsx" });
  c.header('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  c.header('Content-Disposition', 'attachment; filename="template_import_produk.xlsx"');
  return c.body(buffer);
});

// POST /api/products/import
products.post("/import", async (c) => {
  try {
    const body = await c.req.parseBody();
    const file = body['file'] as File;
    if (!file) return c.json({ error: "File tidak ditemukan" }, 400);

    const buffer = await file.arrayBuffer();
    const wb = XLSX.read(buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const data = XLSX.utils.sheet_to_json(ws) as any[];

    if (!data || data.length === 0) return c.json({ error: "File Excel kosong" }, 400);

    let successCount = 0;
    let skippedCount = 0;

    db.transaction(() => {
      for (const row of data) {
        let barcode = row["Barcode"]?.toString().trim();
        let name = row["Nama Produk"]?.toString().trim();
        let categoryName = row["Kategori"]?.toString().trim();
        let stock = Number(row["Stok"]) || 0;
        let minStock = Number(row["Min Stok"]) || 0;
        let purchasePrice = Number(row["Harga Modal"]) || 0;
        let purchaseUnit = row["Satuan Modal"]?.toString().trim() || "";

        if (!name || !categoryName) {
          skippedCount++;
          continue;
        }

        // Check if product exists by barcode OR name to skip
        let existing = null;
        if (barcode) {
          existing = db.prepare("SELECT id FROM products WHERE barcode = ?").get(barcode);
        }
        if (!existing && name) {
          existing = db.prepare("SELECT id FROM products WHERE name = ? COLLATE NOCASE").get(name);
        }
        
        if (existing) {
          skippedCount++;
          continue;
        }

        // Create or get category
        let catRow = db.prepare("SELECT id FROM categories WHERE name = ? COLLATE NOCASE").get(categoryName) as any;
        let categoryId;
        if (!catRow) {
          const res = db.prepare("INSERT INTO categories (name) VALUES (?)").run(categoryName);
          categoryId = res.lastInsertRowid;
        } else {
          categoryId = catRow.id;
        }

        // Insert product
        const resProd = db.prepare("INSERT INTO products (name, category_id, barcode, purchase_price, purchase_unit) VALUES (?, ?, ?, ?, ?)").run(name, categoryId, barcode || null, purchasePrice, purchaseUnit);
        const productId = resProd.lastInsertRowid as number;

        // Insert inventory
        db.prepare("INSERT INTO inventory (product_id, stock_quantity, min_stock_alert) VALUES (?, ?, ?)").run(productId, stock, minStock);

        // Process units
        const unitInsertStmt = db.prepare("INSERT INTO product_units (product_id, unit_name, qty_per_unit, price) VALUES (?, ?, ?, ?)");
        const catUnitCheckStmt = db.prepare("SELECT id FROM category_units WHERE category_id = ? AND unit_name = ? COLLATE NOCASE");
        const catUnitInsertStmt = db.prepare("INSERT OR IGNORE INTO category_units (category_id, unit_name) VALUES (?, ?)");

        for (let i = 1; i <= 3; i++) {
          let uName = row[`Satuan ${i}`]?.toString().trim();
          let uQty = Number(row[`Isi Satuan ${i}`]);
          let uPrice = Number(row[`Harga Jual ${i}`]);

          if (uName && !isNaN(uPrice) && uPrice > 0) {
            if (isNaN(uQty) || uQty <= 0) uQty = 1;
            unitInsertStmt.run(productId, uName, uQty, uPrice);
            
            // Add to category_units if not exists
            if (!catUnitCheckStmt.get(categoryId, uName)) {
              catUnitInsertStmt.run(categoryId, uName);
            }
          }
        }
        successCount++;
      }
    })();

    return c.json({ success: true, message: `Berhasil import ${successCount} produk. Dilewati: ${skippedCount}.`, successCount, skippedCount });
  } catch (e: any) {
    return c.json({ error: e.message || "Gagal memproses file Excel" }, 400);
  }
});
export default products;
