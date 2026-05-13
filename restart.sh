#!/bin/bash
# KAYPOS — Restart Script
# Restart backend + frontend TANPA mereset database

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔄 KAYPOS Restarting..."
echo ""

# Kill existing processes
echo "🛑 Menghentikan proses lama..."
pkill -f "bun.*src/index.ts" 2>/dev/null && echo "   Backend dihentikan" || echo "   Backend tidak berjalan"
pkill -f "vite.*5173" 2>/dev/null && echo "   Frontend dihentikan" || echo "   Frontend tidak berjalan"
sleep 2

# === Backend ===
echo ""
echo "🟢 [Backend] Starting server..."
cd "$SCRIPT_DIR/backend"
bun run dev &
BACKEND_PID=$!
sleep 2

# === Frontend ===
echo "🟢 [Frontend] Starting dev server..."
cd "$SCRIPT_DIR/frontend"
npm run dev &
FRONTEND_PID=$!
sleep 3

# === Info ===
echo ""
echo "=========================================="
echo "  ✅ KAYPOS Berhasil Direstart!"
echo "=========================================="
echo ""
echo "  Frontend: http://localhost:5173"
echo "  Backend:  http://localhost:3000"
echo ""
echo "  Database: TIDAK direset"
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
wait
