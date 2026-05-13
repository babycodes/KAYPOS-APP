// KAYPOS Backend — Seed Data V3 (qty_per_unit model)
import db from "./index";

function seed() {
  console.log("🌱 Seeding database...");

  // --- Users ---
  const stmtUser = db.prepare("INSERT OR IGNORE INTO users (username, name, password, pin, role) VALUES (?, ?, ?, ?, ?)");
  stmtUser.run("admin", "Owner / Admin", "admin123", "000000", "admin");
  stmtUser.run("kasir1", "Kasir 1", "pwkasir", "000000", "kasir");
  stmtUser.run("kasir2", "Kasir 2", "pwkasir", "000000", "kasir");

  // --- Categories + unit NAMES only ---
  const stmtCat = db.prepare("INSERT OR IGNORE INTO categories (name, icon, sort_order) VALUES (?, ?, ?)");
  const stmtCatUnit = db.prepare("INSERT OR IGNORE INTO category_units (category_id, unit_name, sort_order) VALUES (?, ?, ?)");

  stmtCat.run("Plastik", "🛍️", 1);
  stmtCat.run("Material", "🧱", 2);
  stmtCat.run("Keramik", "🏠", 3);
  stmtCat.run("Umum", "🏪", 4);

  const cats = db.prepare("SELECT id, name FROM categories").all() as { id: number; name: string }[];
  const catMap: Record<string, number> = {};
  for (const c of cats) catMap[c.name] = c.id;

  // Plastik: piece, gram, kilo, pack, karung
  stmtCatUnit.run(catMap["Plastik"], "pcs", 1);
  stmtCatUnit.run(catMap["Plastik"], "gram", 2);
  stmtCatUnit.run(catMap["Plastik"], "kilo", 3);
  stmtCatUnit.run(catMap["Plastik"], "pack", 4);
  stmtCatUnit.run(catMap["Plastik"], "karung", 5);

  // Material: cm, meter, batang
  stmtCatUnit.run(catMap["Material"], "cm", 1);
  stmtCatUnit.run(catMap["Material"], "meter", 2);
  stmtCatUnit.run(catMap["Material"], "batang", 3);

  // Keramik: pcs, dus
  stmtCatUnit.run(catMap["Keramik"], "pcs", 1);
  stmtCatUnit.run(catMap["Keramik"], "dus", 2);

  // Umum: pcs, gram, kilo, pack
  stmtCatUnit.run(catMap["Umum"], "pcs", 1);
  stmtCatUnit.run(catMap["Umum"], "gram", 2);
  stmtCatUnit.run(catMap["Umum"], "kilo", 3);
  stmtCatUnit.run(catMap["Umum"], "pack", 4);

  // --- Products with qty_per_unit pricing ---
  const stmtProd = db.prepare("INSERT OR IGNORE INTO products (name, category_id, barcode) VALUES (?, ?, ?)");
  const stmtProdUnit = db.prepare("INSERT OR IGNORE INTO product_units (product_id, unit_name, qty_per_unit, price) VALUES (?, ?, ?, ?)");
  const stmtInv = db.prepare("INSERT OR IGNORE INTO inventory (product_id, stock_quantity, min_stock_alert) VALUES (?, ?, ?)");

  function addProduct(name: string, catName: string, barcode: string, stock: number, minStock: number,
    unitPrices: [string, number, number][] // [unit_name, qty_per_unit, price]
  ) {
    stmtProd.run(name, catMap[catName], barcode);
    const prod = db.prepare("SELECT id FROM products WHERE barcode = ?").get(barcode) as { id: number } | null;
    if (!prod) return;
    for (const [uName, qty, price] of unitPrices) {
      stmtProdUnit.run(prod.id, uName, qty, price);
    }
    stmtInv.run(prod.id, stock, minStock);
  }

  // --- Plastik ---
  // Kantong HD 15: 1 pcs=Rp5, 100gram=Rp120, 1kilo=Rp1200, 1pack(isi50)=Rp250, 1karung=Rp28000
  addProduct("Kantong Plastik HD 15", "Plastik", "8991234001001", 500000, 50000, [
    ["pcs", 1, 5], ["gram", 100, 120], ["kilo", 1, 1200], ["pack", 1, 250], ["karung", 1, 28000]
  ]);
  addProduct("Kantong Plastik HD 24", "Plastik", "8991234001002", 400000, 50000, [
    ["pcs", 1, 8], ["gram", 100, 140], ["kilo", 1, 1400], ["pack", 1, 400], ["karung", 1, 32000]
  ]);
  addProduct("Plastik PP Bening 0.3mm", "Plastik", "8991234001003", 300000, 30000, [
    ["gram", 100, 180], ["kilo", 1, 1800], ["pack", 1, 850]
  ]);
  addProduct("Kantong Kresek Hitam", "Plastik", "8991234001004", 600000, 80000, [
    ["pcs", 1, 3], ["gram", 100, 100], ["kilo", 1, 1000], ["pack", 1, 200], ["karung", 1, 20000]
  ]);
  addProduct("Plastik Wrap Makanan", "Plastik", "8991234001005", 200000, 20000, [
    ["gram", 100, 220], ["kilo", 1, 2200]
  ]);

  // --- Material ---
  // Wall Angle: 1cm=Rp15, 1meter=Rp1500, 1batang(3m)=Rp4300
  addProduct("Wall Angle 3 Meter", "Material", "8991234002001", 9000, 500, [
    ["cm", 1, 15], ["meter", 1, 1500], ["batang", 1, 4300]
  ]);
  addProduct("Hollow Galvalum 4×4", "Material", "8991234002002", 18000, 600, [
    ["cm", 1, 22], ["meter", 1, 2200], ["batang", 1, 12700]
  ]);
  addProduct("Pipa PVC 3/4\"", "Material", "8991234002003", 16000, 400, [
    ["cm", 1, 18], ["meter", 1, 1800], ["batang", 1, 6900]
  ]);
  addProduct("Besi Beton 10mm", "Material", "8991234002004", 24000, 1200, [
    ["cm", 1, 12], ["meter", 1, 1200], ["batang", 1, 13400]
  ]);

  // --- Keramik ---
  addProduct("Keramik 60×60 Granit", "Keramik", "8991234003001", 200, 20, [
    ["pcs", 1, 22500], ["dus", 1, 85000]
  ]);
  addProduct("Keramik 40×40 Polos", "Keramik", "8991234003002", 500, 50, [
    ["pcs", 1, 8500], ["dus", 1, 48000]
  ]);
  addProduct("Keramik Dinding 25×40", "Keramik", "8991234003003", 800, 80, [
    ["pcs", 1, 6000], ["dus", 1, 55000]
  ]);

  // --- Umum ---
  addProduct("Semen Tiga Roda 50Kg", "Umum", "8991234004001", 100, 10, [
    ["pcs", 1, 65000]
  ]);
  addProduct("Cat Tembok Vinilex 5Kg", "Umum", "8991234004002", 50, 5, [
    ["pcs", 1, 85000]
  ]);
  // Paku: 100gram=Rp2200, 1kilo=Rp22000, 1pack(500g)=Rp10500
  addProduct("Paku 5cm", "Umum", "8991234004003", 100000, 5000, [
    ["gram", 100, 2200], ["kilo", 1, 22000], ["pack", 1, 10500]
  ]);
  addProduct("Lem Kayu Rajawali", "Umum", "8991234004004", 80, 10, [
    ["pcs", 1, 15000]
  ]);

  console.log("✅ Seed complete!");
}

seed();
