// KAYPOS — Reports
import { Hono } from "hono";
import db from "../db/index";

const reports = new Hono();

// 28-day chart data
reports.get("/chart28", (c) => {
  const rows = db.prepare(`
    SELECT DATE(created_at) as date, COUNT(*) as count, COALESCE(SUM(total_amount),0) as sales
    FROM transactions WHERE created_at >= datetime('now', '-28 days', 'localtime')
    GROUP BY date ORDER BY date
  `).all() as any[];
  // Fill in missing days with 0
  const result: any[] = [];
  const now = new Date();
  for (let i = 27; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split('T')[0];
    const found = rows.find(r => r.date === dateStr);
    result.push({ date: dateStr, count: found?.count || 0, sales: found?.sales || 0 });
  }
  return c.json(result);
});

reports.get("/daily", (c) => {
  const date = c.req.query("date") || new Date().toISOString().split("T")[0];
  const summary = db.prepare(`
    SELECT COUNT(*) as total_transactions, COALESCE(SUM(total_amount),0) as total_sales,
           COALESCE(AVG(total_amount),0) as avg_transaction
    FROM transactions WHERE DATE(created_at) = ?
  `).get(date);
  const hourly = db.prepare(`
    SELECT strftime('%H', created_at) as hour, COUNT(*) as count, SUM(total_amount) as sales
    FROM transactions WHERE DATE(created_at) = ? GROUP BY hour ORDER BY hour
  `).all(date);
  return c.json({ date, summary, hourly });
});

reports.get("/monthly", (c) => {
  const now = new Date();
  const month = c.req.query("month") || String(now.getMonth() + 1).padStart(2, "0");
  const year = c.req.query("year") || String(now.getFullYear());
  const summary = db.prepare(`
    SELECT COUNT(*) as total_transactions, COALESCE(SUM(total_amount),0) as total_sales
    FROM transactions WHERE strftime('%m', created_at) = ? AND strftime('%Y', created_at) = ?
  `).get(month, year);
  const daily = db.prepare(`
    SELECT DATE(created_at) as date, COUNT(*) as count, SUM(total_amount) as sales
    FROM transactions WHERE strftime('%m', created_at) = ? AND strftime('%Y', created_at) = ?
    GROUP BY date ORDER BY date
  `).all(month, year);
  return c.json({ month, year, summary, daily });
});

reports.get("/products", (c) => {
  const days = Number(c.req.query("days") || 30);
  const rows = db.prepare(`
    SELECT td.product_name, td.unit_used, SUM(td.quantity) as total_qty,
           SUM(td.subtotal) as total_revenue, COUNT(DISTINCT td.transaction_id) as tx_count
    FROM transaction_details td JOIN transactions t ON td.transaction_id = t.id
    WHERE t.created_at >= datetime('now', '-' || ? || ' days', 'localtime')
    GROUP BY td.product_id, td.unit_used ORDER BY total_revenue DESC LIMIT 20
  `).all(days);
  return c.json(rows);
});

// Export transactions as CSV (for Excel)
reports.get("/export", (c) => {
  const type = c.req.query("type") || "day"; // day, month, year
  const date = c.req.query("date") || new Date().toISOString().split("T")[0];
  const month = c.req.query("month") || String(new Date().getMonth() + 1).padStart(2, "0");
  const year = c.req.query("year") || String(new Date().getFullYear());

  let where = "", params: any[] = [];
  let filename = "";
  if (type === "day") {
    where = "WHERE DATE(t.created_at) = ?"; params = [date]; filename = `laporan_${date}.csv`;
  } else if (type === "month") {
    where = "WHERE strftime('%m', t.created_at) = ? AND strftime('%Y', t.created_at) = ?"; params = [month, year]; filename = `laporan_${year}-${month}.csv`;
  } else {
    where = "WHERE strftime('%Y', t.created_at) = ?"; params = [year]; filename = `laporan_${year}.csv`;
  }

  const rows = db.prepare(`
    SELECT t.id, t.created_at as waktu, t.cashier_name as kasir,
      td.product_name as produk, td.unit_used as satuan, td.quantity as qty,
      td.sold_price as harga_satuan, td.subtotal,
      t.total_amount as total, t.paid_amount as bayar, t.change_amount as kembali
    FROM transactions t JOIN transaction_details td ON td.transaction_id = t.id
    ${where} ORDER BY t.created_at DESC
  `).all(...params) as any[];

  // Build CSV with BOM for Excel
  const bom = "\uFEFF";
  const header = "ID,Waktu,Kasir,Produk,Satuan,Qty,Harga Satuan,Subtotal,Total,Bayar,Kembali\n";
  const body = rows.map(r =>
    `${r.id},"${r.waktu}","${r.kasir}","${r.produk}","${r.satuan}",${r.qty},${r.harga_satuan},${r.subtotal},${r.total},${r.bayar},${r.kembali}`
  ).join("\n");

  c.header("Content-Type", "text/csv; charset=utf-8");
  c.header("Content-Disposition", `attachment; filename="${filename}"`);
  return c.body(bom + header + body);
});

export default reports;
