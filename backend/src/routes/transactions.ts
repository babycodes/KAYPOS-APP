// KAYPOS — Transactions V3 (qty_per_unit pricing: subtotal = (qty / qty_per_unit) * price)
import { Hono } from "hono";
import db from "../db/index";

const transactions = new Hono();

transactions.post("/", async (c) => {
  const body = await c.req.json<{
    items: { product_id: number; unit_name: string; quantity: number }[];
    paid_amount: number;
    payment_method?: string;
    note?: string;
  }>();
  const user = c.get("user") as { userId: number; name: string } | undefined;
  if (!body.items?.length) return c.json({ error: "Keranjang kosong" }, 400);
  if (!body.paid_amount) return c.json({ error: "Jumlah bayar wajib" }, 400);

  let totalAmount = 0;
  const details: any[] = [];

  for (const item of body.items) {
    const product = db.prepare("SELECT * FROM products WHERE id = ? AND is_active = 1").get(item.product_id) as any;
    if (!product) return c.json({ error: `Produk ID ${item.product_id} tidak ditemukan` }, 400);

    const unit = db.prepare("SELECT * FROM product_units WHERE product_id = ? AND unit_name = ?")
      .get(item.product_id, item.unit_name) as any;
    if (!unit) return c.json({ error: `Unit '${item.unit_name}' tidak tersedia untuk ${product.name}` }, 400);

    // Check stock availability (including held cart reservations)
    const inv = db.prepare("SELECT stock_quantity FROM inventory WHERE product_id = ?").get(item.product_id) as any;
    let availableStock = inv?.stock_quantity ?? 0;
    // Subtract qty reserved in held carts
    const heldRows = db.prepare("SELECT cart_data FROM held_carts").all() as any[];
    for (const hc of heldRows) {
      try {
        const cartItems = JSON.parse(hc.cart_data);
        for (const ci of cartItems) {
          if (ci.product?.id === item.product_id) availableStock -= (ci.quantity || 0);
        }
      } catch {}
    }
    availableStock = Math.max(0, availableStock);
    if (item.quantity > availableStock) {
      return c.json({ error: `Stok ${product.name} tidak cukup. Tersisa: ${Math.round(availableStock)}, diminta: ${item.quantity}` }, 400);
    }

    // V3: price is for qty_per_unit amount
    // subtotal = (quantity / qty_per_unit) * price
    const pricePerOne = unit.price / unit.qty_per_unit;
    const subtotal = pricePerOne * item.quantity;

    totalAmount += subtotal;
    details.push({
      product_id: product.id, product_name: product.name,
      sold_price: pricePerOne, quantity: item.quantity,
      unit_used: item.unit_name, subtotal,
      stock_deduct: item.quantity // deduct by actual quantity in that unit
    });
  }

  const changeAmount = body.paid_amount - totalAmount;
  if (changeAmount < 0) return c.json({ error: "Pembayaran kurang" }, 400);

  const txResult = db.prepare(`INSERT INTO transactions (cashier_id, cashier_name, total_amount, paid_amount, change_amount, payment_method, note) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(user?.userId || null, user?.name || "Unknown", totalAmount, body.paid_amount, changeAmount, body.payment_method || "cash", body.note || null);
  const txId = txResult.lastInsertRowid as number;

  const stmtDetail = db.prepare("INSERT INTO transaction_details (transaction_id, product_id, product_name, sold_price, quantity, unit_used, subtotal) VALUES (?, ?, ?, ?, ?, ?, ?)");
  const stmtStock = db.prepare("UPDATE inventory SET stock_quantity = MAX(0, stock_quantity - ?), updated_at = datetime('now','localtime') WHERE product_id = ?");

  for (const d of details) {
    stmtDetail.run(txId, d.product_id, d.product_name, d.sold_price, d.quantity, d.unit_used, d.subtotal);
    stmtStock.run(d.stock_deduct, d.product_id);
  }

  return c.json({
    transaction: db.prepare("SELECT * FROM transactions WHERE id = ?").get(txId),
    details: db.prepare("SELECT * FROM transaction_details WHERE transaction_id = ?").all(txId)
  }, 201);
});

transactions.get("/", (c) => {
  const page = Number(c.req.query("page") || 1);
  const limit = Number(c.req.query("limit") || 50);
  const date = c.req.query("date");
  const offset = (page - 1) * limit;
  let where = "", params: any[] = [];
  if (date) { where = "WHERE DATE(t.created_at) = ?"; params.push(date); }
  const total = (db.prepare(`SELECT COUNT(*) as count FROM transactions t ${where}`).get(...params) as any).count;
  const rows = db.prepare(`SELECT * FROM transactions t ${where} ORDER BY t.created_at DESC LIMIT ? OFFSET ?`).all(...params, limit, offset);
  return c.json({ data: rows, total, page, limit });
});

transactions.get("/today", (c) => {
  return c.json(db.prepare(`
    SELECT COUNT(*) as total_transactions, COALESCE(SUM(total_amount),0) as total_sales,
           COALESCE(AVG(total_amount),0) as avg_transaction
    FROM transactions WHERE DATE(created_at) = DATE('now','localtime')
  `).get());
});

transactions.get("/:id", (c) => {
  const tx = db.prepare("SELECT * FROM transactions WHERE id = ?").get(c.req.param("id"));
  if (!tx) return c.json({ error: "Transaksi tidak ditemukan" }, 404);
  return c.json({ transaction: tx, details: db.prepare("SELECT * FROM transaction_details WHERE transaction_id = ?").all(c.req.param("id")) });
});

export default transactions;
