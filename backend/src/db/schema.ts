// KAYPOS Backend — Database Schema V3
// category_units: hanya nama satuan
// product_units: unit_name + qty_per_unit + price
import { Database } from "bun:sqlite";

export function initSchema(db: Database) {
  db.run(`CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    icon TEXT DEFAULT '📦',
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  // V3: category_units hanya menyimpan NAMA satuan (tanpa multiplier)
  db.run(`CREATE TABLE IF NOT EXISTS category_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    unit_name TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    UNIQUE(category_id, unit_name)
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    barcode TEXT UNIQUE,
    purchase_price REAL DEFAULT 0,
    purchase_unit TEXT DEFAULT '',
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now','localtime')),
    updated_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  // V3: product_units menyimpan harga per qty_per_unit
  // Contoh: gram, qty=250, price=1000 → 250 gram = Rp1000
  // Kasir beli 500 gram → (500/250)*1000 = Rp2000
  // Kasir beli 0.25 kilo → 0.25 * 10000 = Rp2500
  db.run(`CREATE TABLE IF NOT EXISTS product_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_name TEXT NOT NULL,
    qty_per_unit REAL NOT NULL DEFAULT 1,
    price REAL NOT NULL,
    UNIQUE(product_id, unit_name)
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS inventory (
    product_id INTEGER PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    stock_quantity REAL NOT NULL DEFAULT 0,
    min_stock_alert REAL DEFAULT 0,
    updated_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    pin TEXT NOT NULL DEFAULT '000000',
    role TEXT NOT NULL DEFAULT 'kasir',
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cashier_id INTEGER REFERENCES users(id),
    cashier_name TEXT,
    total_amount REAL NOT NULL,
    paid_amount REAL NOT NULL,
    change_amount REAL NOT NULL,
    payment_method TEXT DEFAULT 'cash',
    note TEXT,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS transaction_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL,
    product_name TEXT NOT NULL,
    sold_price REAL NOT NULL,
    purchase_price REAL DEFAULT 0,
    quantity REAL NOT NULL,
    unit_used TEXT NOT NULL,
    subtotal REAL NOT NULL
  )`);

  // Held/Parked carts — shared across all devices
  db.run(`CREATE TABLE IF NOT EXISTS held_carts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    cart_data TEXT NOT NULL,
    total REAL NOT NULL DEFAULT 0,
    created_by INTEGER REFERENCES users(id),
    created_by_name TEXT,
    created_at TEXT DEFAULT (datetime('now','localtime'))
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )`);

  const stmtSetting = db.prepare("INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)");
  stmtSetting.run("store_name", "KAYPOS Store");
  stmtSetting.run("store_address", "");
  stmtSetting.run("store_phone", "");
  stmtSetting.run("printer_port", "/dev/usb/lp0");
}
