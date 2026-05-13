// KAYPOS — Reports
import { Hono } from "hono";
import db from "../db/index";

const reports = new Hono();

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

export default reports;
