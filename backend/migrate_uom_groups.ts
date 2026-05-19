import { Database } from "bun:sqlite";

const DB_PATH = import.meta.dir + "/pos_data.db";
const db = new Database(DB_PATH);

console.log("Adding uom_groups to categories...");
try {
  db.run("ALTER TABLE categories ADD COLUMN uom_groups TEXT DEFAULT '[]'");
  console.log("Success: Added uom_groups");
} catch (e: any) {
  if (e.message.includes("duplicate column")) {
    console.log("Column already exists.");
  } else {
    console.error("Error:", e.message);
  }
}

db.close();
