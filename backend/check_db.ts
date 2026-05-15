import { Database } from "bun:sqlite";
const db = new Database("pos_data.db");
console.log(db.prepare("PRAGMA table_info(transaction_details)").all());
