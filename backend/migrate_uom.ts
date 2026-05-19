import { Database } from "bun:sqlite";

const DB_PATH = import.meta.dir + "/pos_data.db";
const db = new Database(DB_PATH);

console.log("Adding default_base_unit to categories...");
try {
  db.run("ALTER TABLE categories ADD COLUMN default_base_unit TEXT DEFAULT 'pcs'");
  console.log("Success: Added default_base_unit");
} catch (e: any) {
  if (e.message.includes("duplicate column")) {
    console.log("Column already exists.");
  } else {
    console.error("Error:", e.message);
  }
}

console.log("Adding qty_per_unit to category_units...");
try {
  db.run("ALTER TABLE category_units ADD COLUMN qty_per_unit REAL DEFAULT 1");
  console.log("Success: Added qty_per_unit");
} catch (e: any) {
  if (e.message.includes("duplicate column")) {
    console.log("Column already exists.");
  } else {
    console.error("Error:", e.message);
  }
}

db.close();
