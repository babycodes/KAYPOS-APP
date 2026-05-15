import { Database } from "bun:sqlite";
const db = new Database("pos_data.db");
try {
  db.run("ALTER TABLE transaction_details ADD COLUMN purchase_price REAL DEFAULT 0");
  console.log("Added purchase_price to transaction_details");
} catch (e) { console.log(e.message); }

try {
  db.run("ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0");
  console.log("Added purchase_price to products");
} catch (e) { console.log(e.message); }

try {
  db.run("ALTER TABLE products ADD COLUMN purchase_unit TEXT DEFAULT ''");
  console.log("Added purchase_unit to products");
} catch (e) { console.log(e.message); }
