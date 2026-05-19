// KAYPOS — Print Route (ESC/POS for 58mm thermal via /dev/usb/lp0)
import { Hono } from "hono";
import db from "../db/index";

const print = new Hono();

// GET /api/print/detect — Detect connected USB printers (Moved to Frontend)
print.get("/detect", (c) => {
  return c.json({ printers: [], current: '' });
});

// ESC/POS Constants for 58mm (32 char width)
const ESC = "\x1b";
const GS = "\x1d";
const WIDTH = 32;

function cmd(hex: string): string { return String.fromCharCode(...hex.split(' ').map(h => parseInt(h, 16))); }

const INIT = cmd("1B 40");           // Initialize printer
const BOLD_ON = cmd("1B 45 01");     // Bold on
const BOLD_OFF = cmd("1B 45 00");    // Bold off
const ALIGN_CENTER = cmd("1B 61 01");
const ALIGN_LEFT = cmd("1B 61 00");
const ALIGN_RIGHT = cmd("1B 61 02");
const DOUBLE_HEIGHT = cmd("1B 21 10"); // Double height
const NORMAL_SIZE = cmd("1B 21 00");   // Normal size
const CUT = cmd("1D 56 42 00");        // Full cut
const FEED_3 = "\n\n\n";

function padLine(left: string, right: string): string {
  const space = WIDTH - left.length - right.length;
  if (space <= 0) return left.substring(0, WIDTH - right.length) + right;
  return left + " ".repeat(space) + right;
}

function centerText(text: string): string {
  const pad = Math.max(0, Math.floor((WIDTH - text.length) / 2));
  return " ".repeat(pad) + text;
}

function dashedLine(): string {
  return "-".repeat(WIDTH);
}

function formatRp(amount: number): string {
  if (amount < 1 && amount > 0) return `Rp${amount.toFixed(2)}`;
  return `Rp${Math.round(amount).toLocaleString("id-ID")}`;
}

// POST /api/print/receipt — Print a receipt by transaction ID
print.post("/receipt", async (c) => {
  const { transaction_id } = await c.req.json<{ transaction_id: number }>();
  if (!transaction_id) return c.json({ error: "transaction_id wajib" }, 400);

  const tx = db.prepare("SELECT * FROM transactions WHERE id = ?").get(transaction_id) as any;
  if (!tx) return c.json({ error: "Transaksi tidak ditemukan" }, 404);

  const details = db.prepare("SELECT * FROM transaction_details WHERE transaction_id = ?").all(transaction_id) as any[];

  // Get store settings
  const settings: Record<string, string> = {};
  const rows = db.prepare("SELECT key, value FROM settings").all() as { key: string; value: string }[];
  for (const r of rows) settings[r.key] = r.value;

  const storeName = settings.store_name || "KAYPOS Store";
  const storeAddr = settings.store_address || "";
  const storePhone = settings.store_phone || "";

  // Build receipt
  let receipt = INIT;

  // Header
  receipt += ALIGN_CENTER;
  receipt += DOUBLE_HEIGHT + BOLD_ON;
  receipt += storeName + "\n";
  receipt += NORMAL_SIZE + BOLD_OFF;
  if (storeAddr) receipt += storeAddr + "\n";
  if (storePhone) receipt += "Tel: " + storePhone + "\n";
  receipt += "\n";

  // Transaction info
  receipt += ALIGN_LEFT;
  receipt += dashedLine() + "\n";
  const txDate = new Date(tx.created_at);
  const dateStr = txDate.toLocaleDateString("id-ID", { day: "2-digit", month: "2-digit", year: "numeric" });
  const timeStr = txDate.toLocaleTimeString("id-ID", { hour: "2-digit", minute: "2-digit" });
  receipt += padLine(`#${tx.id}`, `${dateStr} ${timeStr}`) + "\n";
  receipt += padLine("Kasir:", tx.cashier_name || "-") + "\n";
  receipt += dashedLine() + "\n";

  // Items
  for (const d of details) {
    // Product name (full line)
    receipt += d.product_name + "\n";
    
    const product = db.prepare("SELECT base_unit FROM products WHERE id = ?").get(d.product_id) as any;
    const baseUnit = product ? (product.base_unit || 'pcs') : 'pcs';
    const allUnits = db.prepare("SELECT * FROM product_units WHERE product_id = ?").all(d.product_id) as any[];
    const unitDef = allUnits.find(u => u.unit_name === d.unit_used);
    const multiplier = unitDef ? unitDef.qty_per_unit : 1;
    
    const totalBase = d.quantity * multiplier;
    
    const sortedUnits = [...allUnits].sort((a, b) => b.qty_per_unit - a.qty_per_unit);
    let largestValidMultiplier = 0;
    for (const u of sortedUnits) {
      if (totalBase >= u.qty_per_unit) {
        largestValidMultiplier = u.qty_per_unit;
        break;
      }
    }

    let displayStr = "";
    if (largestValidMultiplier > multiplier) {
      let remaining = totalBase;
      let stockStr = "";
      for (const u of sortedUnits) {
        if (u.qty_per_unit > 1 && remaining >= u.qty_per_unit) {
          const majorQty = Math.floor(remaining / u.qty_per_unit);
          remaining = remaining - (majorQty * u.qty_per_unit);
          stockStr += `${majorQty} ${u.unit_name} `;
        }
      }
      if (remaining > 0.001 || stockStr === "") {
        const remStr = remaining % 1 === 0 ? remaining.toString() : remaining.toFixed(2).replace(/\.?0+$/, '');
        stockStr += `${remStr} ${baseUnit}`;
      }
      displayStr = stockStr.trim();
    } else {
      const qtyStr = d.quantity % 1 === 0 ? d.quantity.toString() : d.quantity.toFixed(2).replace(/\.?0+$/, '');
      if (multiplier > 1) {
        const multStr = multiplier % 1 === 0 ? multiplier.toString() : multiplier.toFixed(2).replace(/\.?0+$/, '');
        displayStr = `${qtyStr}x ${multStr} ${baseUnit}`;
      } else {
        displayStr = `${qtyStr}x ${baseUnit}`;
      }
    }

    // Qty x Price = Subtotal (right-aligned)
    const qtyInfo = `  ${displayStr} @ ${formatRp(d.sold_price)}`;
    const subtotal = formatRp(d.subtotal);
    receipt += padLine(qtyInfo, subtotal) + "\n";
  }

  receipt += dashedLine() + "\n";

  // Totals
  receipt += BOLD_ON;
  receipt += padLine("TOTAL", formatRp(tx.total_amount)) + "\n";
  receipt += BOLD_OFF;
  receipt += padLine("Bayar", formatRp(tx.paid_amount)) + "\n";
  receipt += padLine("Kembali", formatRp(tx.change_amount)) + "\n";
  receipt += dashedLine() + "\n";

  // Footer
  receipt += ALIGN_CENTER;
  receipt += "\n";
  receipt += "Terima Kasih\n";
  receipt += "Barang yang sudah dibeli\n";
  receipt += "tidak dapat dikembalikan\n";
  receipt += FEED_3;
  receipt += CUT;

  // Send to frontend
  try {
    const buf = Buffer.from(receipt, "binary");
    return c.json({ success: true, receipt_base64: buf.toString("base64"), message: "Nota siap dicetak" });
  } catch (e: any) {
    return c.json({ error: `Gagal format nota: ${e.message}` }, 500);
  }
});

// POST /api/print/test — Test print
print.post("/test", async (c) => {
  const settings: Record<string, string> = {};
  const rows = db.prepare("SELECT key, value FROM settings").all() as { key: string; value: string }[];
  for (const r of rows) settings[r.key] = r.value;

  try {
    let test = INIT;
    test += ALIGN_CENTER;
    test += DOUBLE_HEIGHT + BOLD_ON;
    test += "KAYPOS\n";
    test += NORMAL_SIZE + BOLD_OFF;
    test += "Test Print OK!\n";
    test += dashedLine() + "\n";
    test += new Date().toLocaleString("id-ID") + "\n";
    test += FEED_3;
    test += CUT;

    const buf = Buffer.from(test, "binary");
    return c.json({ success: true, receipt_base64: buf.toString("base64"), message: "Test print siap!" });
  } catch (e: any) {
    return c.json({ error: `Gagal: ${e.message}` }, 500);
  }
});

export default print;
