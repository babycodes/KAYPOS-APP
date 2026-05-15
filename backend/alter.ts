import { Database } from "bun:sqlite";
const db = new Database("kaypos.db");
try { db.run("ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0;"); } catch(e) {}
try { db.run("ALTER TABLE products ADD COLUMN purchase_unit TEXT DEFAULT '';"); } catch(e) {}
try { db.run("ALTER TABLE transaction_details ADD COLUMN purchase_price REAL DEFAULT 0;"); } catch(e) {}
console.log("DB Updated");
