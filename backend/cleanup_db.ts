import { Database } from "bun:sqlite";

const DB_PATH = import.meta.dir + "/pos_data.db";
const db = new Database(DB_PATH);

console.log("Cleaning up categories table...");
try {
  db.run("ALTER TABLE categories DROP COLUMN uom_groups");
  console.log("Dropped uom_groups from categories");
} catch (e: any) {
  console.log("uom_groups not dropped:", e.message);
}

try {
  db.run("ALTER TABLE categories DROP COLUMN default_base_unit");
  console.log("Dropped default_base_unit from categories");
} catch (e: any) {
  console.log("default_base_unit not dropped:", e.message);
}

console.log("Cleaning up category_units table...");
try {
  db.run("ALTER TABLE category_units DROP COLUMN qty_per_unit");
  console.log("Dropped qty_per_unit from category_units");
} catch (e: any) {
  console.log("qty_per_unit not dropped:", e.message);
}

db.close();
