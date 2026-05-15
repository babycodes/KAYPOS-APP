#!/bin/bash
# KAYPOS — Start Script
# Otomatis install dependencies, seed database, dan jalankan backend + frontend

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 KAYPOS Starting..."
echo ""

# === Backend ===
echo "📦 [Backend] Installing dependencies..."
cd "$SCRIPT_DIR/backend"
bun install --frozen-lockfile 2>/dev/null || bun install

# Seed database (safe to run multiple times — uses INSERT OR IGNORE)
if [ ! -f "$SCRIPT_DIR/backend/pos_data.db" ]; then
    echo "🌱 [Backend] Database tidak ditemukan, menjalankan seed..."
    bun run seed
else
    echo "✅ [Backend] Database sudah ada, skip seed"
fi

echo "🟢 [Backend] Starting server..."
bun run dev &
BACKEND_PID=$!
sleep 2

# === Frontend ===
echo ""
echo "📦 [Frontend] Installing dependencies..."
cd "$SCRIPT_DIR/frontend"
~/.local/flutter/bin/flutter pub get

echo "🟢 [Frontend] Starting dev server..."
~/.local/flutter/bin/flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0 &
FRONTEND_PID=$!
sleep 3

# === Info ===
echo ""
echo "=========================================="
echo "  🎉 KAYPOS Berhasil Dijalankan!"
echo "=========================================="
echo ""
echo "  Frontend: http://localhost:8080"
echo "  Backend:  http://localhost:3000"
echo ""
echo "  Akun Default:"
echo "    Admin  → admin / admin123"
echo "    Kasir  → kasir1 / pwkasir"
echo ""
echo "  Tekan Ctrl+C untuk menghentikan"
echo "=========================================="
echo ""

# Trap Ctrl+C to kill both
cleanup() {
    echo ""
    echo "🛑 Menghentikan KAYPOS..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    wait $BACKEND_PID 2>/dev/null
    wait $FRONTEND_PID 2>/dev/null
    echo "✅ KAYPOS dihentikan"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait for both processes
wait
