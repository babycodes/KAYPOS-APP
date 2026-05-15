// KAYPOS — Settings Routes
import { Hono } from "hono";
import db from "../db/index";

const settings = new Hono();

settings.get("/", (c) => {
  const rows = db.prepare("SELECT key, value FROM settings").all() as any[];
  const config: Record<string, string> = {};
  for (const r of rows) {
    config[r.key] = r.value;
  }
  return c.json(config);
});

settings.put("/", async (c) => {
  const body = await c.req.json<Record<string, string>>();
  const stmt = db.prepare("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value");
  db.transaction(() => {
    for (const [key, value] of Object.entries(body)) {
      stmt.run(key, value);
    }
  })();
  return c.json({ success: true });
});

export default settings;
