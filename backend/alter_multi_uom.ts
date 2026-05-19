import { Database } from "bun:sqlite";

const db = new Database("pos_data.db");
try {
  db.run("ALTER TABLE products ADD COLUMN base_unit TEXT DEFAULT 'pcs'");
  console.log("Success: Added base_unit to products");
} catch (e: any) {
  if (e.message.includes("duplicate column name")) {
    console.log("Column base_unit already exists.");
  } else {
    console.error("Error:", e.message);
  }
}
