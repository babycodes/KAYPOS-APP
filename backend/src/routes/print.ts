// KAYPOS — Print Route (ESC/POS for 58mm thermal via /dev/usb/lp0)
import { Hono } from "hono";
import db from "../db/index";
import { writeFileSync, readdirSync, existsSync, statSync, accessSync, constants } from "fs";
import { execSync } from "child_process";

const print = new Hono();

// GET /api/print/detect — Detect connected USB printers
print.get("/detect", (c) => {
  const printers: { path: string; name: string; writable: boolean }[] = [];

  // Scan common Linux USB printer paths
  const scanDirs = ["/dev/usb", "/dev"];
  const patterns = [/^lp\d+$/];

  for (const dir of scanDirs) {
    if (!existsSync(dir)) continue;
    try {
      const files = readdirSync(dir);
      for (const f of files) {
        if (!patterns.some(p => p.test(f))) continue;
        const fullPath = `${dir}/${f}`;
        try {
          const stat = statSync(fullPath);
          if (!stat.isCharacterDevice() && !stat.isBlockDevice() && !stat.isFile()) continue;
          let writable = false;
          try { accessSync(fullPath, constants.W_OK); writable = true; } catch {}
          // Try to get printer name via lpinfo or udevadm
          let name = fullPath;
          try {
            const udev = execSync(`udevadm info --query=property --name=${fullPath} 2>/dev/null | grep -E "ID_MODEL=|ID_VENDOR=" | head -2`, { timeout: 2000 }).toString().trim();
            const vendor = udev.match(/ID_VENDOR=(.*)/)?.[1] || '';
            const model = udev.match(/ID_MODEL=(.*)/)?.[1] || '';
            if (vendor || model) name = `${vendor} ${model}`.trim().replace(/_/g, ' ');
          } catch {}
          printers.push({ path: fullPath, name, writable });
        } catch {}
      }
    } catch {}
  }

  return c.json({ printers, current: (db.prepare("SELECT value FROM settings WHERE key = 'printer_port'").get() as any)?.value || '/dev/usb/lp0' });
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
  const printerPort = settings.printer_port || "/dev/usb/lp0";

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
    // Qty x Price = Subtotal (right-aligned)
    const qtyInfo = `  ${d.quantity} ${d.unit_used} x ${formatRp(d.sold_price)}`;
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

  // Send to printer
  try {
    const buf = Buffer.from(receipt, "binary");
    writeFileSync(printerPort, buf);
    return c.json({ success: true, message: "Nota berhasil dicetak!" });
  } catch (e: any) {
    return c.json({ error: `Gagal cetak: ${e.message}. Pastikan printer terhubung di ${printerPort}` }, 500);
  }
});

// POST /api/print/test — Test print
print.post("/test", async (c) => {
  const settings: Record<string, string> = {};
  const rows = db.prepare("SELECT key, value FROM settings").all() as { key: string; value: string }[];
  for (const r of rows) settings[r.key] = r.value;
  const printerPort = settings.printer_port || "/dev/usb/lp0";

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

    writeFileSync(printerPort, Buffer.from(test, "binary"));
    return c.json({ success: true, message: "Test print berhasil!" });
  } catch (e: any) {
    return c.json({ error: `Gagal: ${e.message}` }, 500);
  }
});

export default print;
