// KAYPOS — Main Server (Bun.js + Hono)
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { requireAuth, requireAdmin } from "./middleware/auth";

// Route imports
import authRoutes from "./routes/auth";
import categoriesRoutes from "./routes/categories";
import productsRoutes from "./routes/products";
import inventoryRoutes from "./routes/inventory";
import transactionsRoutes from "./routes/transactions";
import reportsRoutes from "./routes/reports";
import usersRoutes from "./routes/users";
import backupRoutes from "./routes/backup";
import printRoutes from "./routes/print";
import heldCartsRoutes from "./routes/held-carts";

const app = new Hono();

// Global middleware
app.use("*", cors({ origin: "*" }));
app.use("*", logger());

// Health check
app.get("/api/health", (c) => c.json({ status: "ok", time: new Date().toISOString() }));

// Public routes
app.route("/api/auth", authRoutes);

// Protected routes (require login)
app.use("/api/categories/*", requireAuth);
app.use("/api/products/*", requireAuth);
app.use("/api/inventory/*", requireAuth);
app.use("/api/transactions/*", requireAuth);
app.use("/api/reports/*", requireAuth);
app.use("/api/users/*", requireAuth, requireAdmin);
app.use("/api/backup/*", requireAuth, requireAdmin);
app.use("/api/print/*", requireAuth);
app.use("/api/held-carts/*", requireAuth);

app.route("/api/categories", categoriesRoutes);
app.route("/api/products", productsRoutes);
app.route("/api/inventory", inventoryRoutes);
app.route("/api/transactions", transactionsRoutes);
app.route("/api/reports", reportsRoutes);
app.route("/api/users", usersRoutes);
app.route("/api/held-carts", heldCartsRoutes);
app.route("/api/backup", backupRoutes);
app.route("/api/print", printRoutes);

const PORT = Number(process.env.PORT || 3000);

// Get LAN IPs
import { networkInterfaces } from "os";
function getLanIps(): string[] {
  const nets = networkInterfaces();
  const ips: string[] = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) ips.push(net.address);
    }
  }
  return ips;
}

const lanIps = getLanIps();
console.log(`🚀 KAYPOS Backend running on:`);
console.log(`   Local:   http://localhost:${PORT}`);
lanIps.forEach(ip => console.log(`   Network: http://${ip}:${PORT}`));
if (lanIps.length === 0) console.log(`   Network: Tidak terdeteksi`);

export default {
  port: PORT,
  hostname: "0.0.0.0",
  fetch: app.fetch,
};
