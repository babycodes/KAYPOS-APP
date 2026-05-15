// KAYPOS — Backup & Restore (download to device)
import { Hono } from "hono";
import db from "../db/index";
import { readFileSync } from "fs";

const backup = new Hono();

const DB_PATH = import.meta.dir + "/../../pos_data.db";

// GET /api/backup/download — download .db file directly to client device
backup.get("/download", (c) => {
  // Force WAL checkpoint before backup
  db.run("PRAGMA wal_checkpoint(TRUNCATE)");

  const fileBuffer = readFileSync(DB_PATH);
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const filename = `kaypos_backup_${timestamp}.db`;

  return new Response(fileBuffer, {
    headers: {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Content-Length": String(fileBuffer.length),
    },
  });
});

// POST /api/backup/restore — upload .db file to replace current
backup.post("/restore", async (c) => {
  const formData = await c.req.formData();
  const file = formData.get("database") as File | null;

  if (!file) return c.json({ error: "File database (.db) wajib diupload" }, 400);
  if (!file.name.endsWith(".db")) return c.json({ error: "File harus berformat .db" }, 400);

  try {
    const buffer = await file.arrayBuffer();
    // Close current db and write new one
    db.close();
    await Bun.write(DB_PATH, buffer);
    return c.json({ success: true, message: "Database berhasil di-restore. Restart server untuk menerapkan." });
  } catch (e: any) {
    return c.json({ error: e.message || "Gagal restore" }, 500);
  }
});



export default backup;
