# KAYPOS — Sistem Point of Sale Modern

**KAYPOS** adalah sistem kasir (POS) modern berbasis web yang dirancang untuk bisnis retail & F&B. Dibangun dengan teknologi terkini, mendukung multi-device, multi-kasir, dan printer thermal ESC/POS.

## ✨ Fitur Utama

### 🛒 Kasir
- **Tampilan mobile-first** — UI responsif untuk HP, tablet, dan desktop
- **Pencarian produk** real-time dengan filter kategori
- **Multi-satuan** — produk bisa dijual per pcs, pack, dus, kg, dll
- **Keranjang belanja** dengan increment/decrement item
- **Pembayaran** dengan kalkulasi kembalian otomatis
- **Struk/Receipt** — tampilan struk digital + cetak ke printer thermal

### 🔄 Multi-Transaksi (Hold/Park)
- **Tahan transaksi** — simpan keranjang pelanggan yang belum selesai
- **Multi-antrian** — hingga 10 transaksi ditahan bersamaan
- **Cross-device** — transaksi ditahan tersimpan di database, bisa diakses dari device lain
- **Real-time sync** — polling setiap 5 detik antar device
- **Nama custom** — beri nama inisial pembeli pada setiap antrian
- **Panggil kembali** — lanjutkan transaksi yang ditahan kapan saja

### 🔐 Keamanan
- **PIN 6 digit** — lock screen dengan numpad untuk akses cepat
- **3x percobaan** — setelah 3x PIN salah, otomatis logout
- **Ganti akun** — tombol untuk login user lain tanpa restart
- **Lock manual** — tombol gembok untuk mengunci layar
- **Ganti password & PIN** — dari profil, masing-masing tombol simpan terpisah

### 📊 Rekap & Riwayat
- **Dashboard hari ini** — total transaksi, total penjualan, rata-rata
- **Riwayat transaksi** — daftar transaksi hari ini dengan cetak ulang struk
- **Laporan harian & bulanan** — grafik dan analisis penjualan

### 🖨️ Printer
- **Auto-detect** — deteksi otomatis printer USB yang terhubung
- **ESC/POS** — kompatibel dengan printer thermal 58mm
- **Test print** — tombol test langsung dari pengaturan
- **Multi-printer** — pilih dari daftar printer yang terdeteksi

### 👤 Admin Panel
- **Responsive sidebar** — hamburger menu di mobile, collapsible di desktop
- **Manajemen produk** — tambah, edit, hapus produk dengan satuan
- **Manajemen kategori** — organisasi produk
- **Inventaris/Stok** — tracking stok masuk
- **Karyawan** — kelola akun kasir
- **Pengaturan toko** — nama, alamat, telepon untuk struk
- **Backup & Restore** — download/upload database

### 🌐 Jaringan
- **Multi-device** — akses dari HP lain via WiFi (LAN)
- **Auto IP detection** — server menampilkan IP jaringan saat startup
- **Dynamic API** — frontend otomatis menyesuaikan hostname

---

## 🚀 Instalasi

### Prasyarat
- [Bun](https://bun.sh) (runtime JavaScript)
- [Node.js](https://nodejs.org) v18+ (untuk frontend tooling)

### 1. Clone repository
```bash
git clone git@github.com:babycodes/KAYPOS.git
cd KAYPOS
```

### 2. Jalankan (otomatis install + seed + start)
```bash
./start.sh
```
> Script ini otomatis: install dependencies → seed database (jika pertama kali) → jalankan backend & frontend

### 3. Restart (tanpa reset database)
```bash
./restart.sh
```
> Hanya restart backend & frontend, data tetap aman

### 4. Akses
```
Lokal:    http://localhost:5173
Jaringan: http://<IP-SERVER>:5173  (lihat output backend)
```

### Manual (opsional)
```bash
# Install manual
cd backend && bun install
cd ../frontend && npm install

# Seed database (hanya pertama kali)
cd ../backend && bun run seed

# Jalankan terpisah
cd backend && bun run dev      # Terminal 1
cd frontend && npm run dev     # Terminal 2
```

---

## 🔑 Akun Default

| Role | Username | Password | PIN |
|------|----------|----------|-----|
| Admin | `admin` | `admin123` | `000000` |
| Kasir 1 | `kasir1` | `pwkasir` | `000000` |
| Kasir 2 | `kasir2` | `pwkasir` | `000000` |

> ⚠️ **Segera ganti password dan PIN default setelah login pertama!**

---

## 📱 Panduan Penggunaan

### Login
1. Buka aplikasi di browser
2. Masukkan username dan password
3. Kasir diarahkan ke halaman kasir, Admin ke dashboard admin

### Melakukan Transaksi
1. Pilih produk dari daftar atau cari menggunakan search
2. Pilih satuan jika produk memiliki multi-satuan
3. Atur jumlah di keranjang (+ / -)
4. Tekan **💳 BAYAR SEKARANG**
5. Masukkan jumlah uang yang dibayar
6. Tekan **Proses** — struk akan muncul
7. Cetak struk jika diperlukan

### Menahan Transaksi (Park/Hold)
1. Saat ada pelanggan yang belum selesai, tekan **⏳ Tahan**
2. Beri nama antrian (contoh: "Pak Ahmad")
3. Transaksi tersimpan — keranjang menjadi kosong
4. Layani pelanggan berikutnya
5. Untuk melanjutkan, tekan badge **Ditahan** di toolbar
6. Tekan **Panggil** pada antrian yang diinginkan
7. Keranjang terisi kembali — lanjutkan transaksi

### Mengunci Layar
1. Tekan tombol 🔒 (gembok merah) di toolbar
2. Masukkan PIN 6 digit untuk membuka
3. Jika PIN salah 3x → otomatis logout
4. Bisa tekan **Ganti Akun** untuk login user lain

### Cetak Ulang Struk
1. Tekan **📄 Riwayat** di bottom navbar
2. Cari transaksi yang dimaksud
3. Tekan **Lihat / Cetak Ulang**

### Mengatur Printer
1. Login sebagai admin → **Pengaturan**
2. Printer akan terdeteksi otomatis
3. Pilih printer dari daftar yang tersedia
4. Tekan **Test Print** untuk memastikan
5. Simpan pengaturan

---

## 🏗️ Teknologi

| Komponen | Teknologi |
|----------|-----------|
| Backend | [Bun](https://bun.sh) + [Hono](https://hono.dev) |
| Database | SQLite (via `bun:sqlite`) |
| Frontend | [SvelteKit](https://kit.svelte.dev) + Svelte 5 |
| Styling | [TailwindCSS v4](https://tailwindcss.com) |
| Printer | ESC/POS protocol (58mm thermal) |

## 📁 Struktur Proyek

```
KAYPOS/
├── start.sh               # 🚀 Jalankan pertama kali
├── restart.sh             # 🔄 Restart tanpa reset DB
├── backend/
│   ├── src/
│   │   ├── db/           # Schema, seed, database
│   │   ├── middleware/    # Auth middleware
│   │   ├── routes/        # API endpoints
│   │   └── index.ts       # Server entry
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/  # UI components
│   │   │   ├── stores/      # Auth store
│   │   │   ├── actions/     # Svelte actions
│   │   │   └── api.ts       # API client
│   │   └── routes/
│   │       ├── kasir/       # Kasir page
│   │       ├── admin/       # Admin panel
│   │       └── login/       # Login page
│   └── package.json
└── README.md
```

---

## 📄 Lisensi

MIT License — Bebas digunakan untuk keperluan komersial maupun pribadi.
# KAYPOS-FLUTTER
