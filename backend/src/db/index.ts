// KAYPOS Backend — Database Init (bun:sqlite + WAL)
import { Database } from "bun:sqlite";
import { initSchema } from "./schema";

const DB_PATH = import.meta.dir + "/../../pos_data.db";

const db = new Database(DB_PATH);

// PRD §3: WAL mode wajib untuk concurrent I/O
db.run("PRAGMA journal_mode = WAL");
db.run("PRAGMA synchronous = NORMAL");
db.run("PRAGMA foreign_keys = ON");
db.run("PRAGMA busy_timeout = 5000");

// Init schema on first run
initSchema(db);

export default db;
