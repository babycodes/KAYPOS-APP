# Product Requirements Document (PRD): STB Local POS System (Google Material 3 Edition)

## 1. Product Overview
Sistem Point of Sale (POS) berbasis Web/PWA yang di-hosting secara lokal menggunakan Set-Top Box (STB) berkapasitas RAM 2GB dan CPU 2-Core (OS Linux Armbian). Sistem dirancang beroperasi 100% tanpa internet (intranet offline), tanpa biaya langganan, dengan target respons API di bawah 10ms.

## 2. Target Market & Flexibility (Dynamic Units)
Sistem bersifat agnostik dan mendukung berbagai jenis usaha (Toko Plastik, Material Konstruksi, Retail, F&B). 
Fokus utama adalah fleksibilitas "Dynamic Unit Conversion" (Konversi Satuan Dinamis) untuk melayani penjualan fraksional, pecahan, atau *bundling*.
*   **Kasus Usaha Plastik:** Penjualan bisa dalam gram, kilo, pack, atau karung (Sistem paham bahwa 1 Karung = 25 Kilo = 25.000 Gram).
*   **Kasus Material Bangunan:** Penjualan material bisa dipotong (misal: *wall angle* 3 meter dijual per sentimeter), atau keramik (penjualan per dus untuk kebutuhan luasan lantai, misal 15 m2, di mana sistem memotong stok 4 pcs/keping per 1 dus ukuran 60x60).

## 3. Tech Stack
*   **Backend / API:** Bun.js + Hono (Fokus pada latensi ultra-rendah & minimal konsumsi RAM STB).
*   **Database:** SQLite3 (Wajib: Mode WAL / Write-Ahead Logging diaktifkan untuk *concurrent I/O* tanpa antrean).
*   **Frontend / UI:** SvelteKit + Tailwind CSS (Tidak ada *server-side rendering* yang membebani STB, murni dirender oleh klien).
*   **Distribusi Klien:** Progressive Web App (PWA). Bisa di-"Install to Home Screen" di Chrome/Safari Tablet Kasir sehingga beroperasi 100% layaknya *Native App* (Fullscreen, aset ter-*cache* lokal).

## 4. UI/UX Guidelines (Google Material Design 3)
*   **Paradigma Desain:** Wajib mengadopsi Google Material Design 3 (M3). Antarmuka harus sangat bersih, modern, dan intuitif bagi orang awam.
*   **Animasi & Interaksi:** Harus memiliki *fluid animations*. Berikan efek 'Ripple' saat tombol ditekan. Transisi perpindahan kategori barang menggunakan efek *fade-slide* dengan *easing* `cubic-bezier` (cepat di awal, lambat di akhir) dengan durasi maksimal 300ms.
*   **Ergonomi Kasir:** Area sentuh (Touch-Target) minimal 48x48dp. Dukungan penuh untuk Mode Gelap (*Dark Mode*) dan Mode Terang (*Light Mode*).
*   **Responsivitas:** Layout *Grid* dinamis untuk Tablet (layar lanskap sebagai kasir utama) dan *List view* untuk layar HP (untuk pelayan keliling).

## 5. Core Features
1.  **Fast Checkout & Shortcut:** Sistem keranjang belanja dengan *shortcut* nominal uang pas dan uang pecahan besar (Rp50.000, Rp100.000) agar transaksi selesai dalam hitungan detik.
2.  **Telegram Auto-Backup:** *Cronjob* atau sistem otomatis yang berjalan setiap tengah malam, melakukan kompresi *file* `pos_data.db`, lalu mengirimkannya langsung ke Telegram Admin.
3.  **One-Click Restore:** Fitur unggah *file* `.db` di *dashboard* admin untuk memulihkan sistem secara instan jika STB/Flashdisk diganti.
4.  **Role-Based Access:** PIN *login* cepat untuk Kasir, dan *password* penuh untuk *dashboard* Admin (mengatur stok, laba rugi, karyawan).

## 6. Database Schema Core Logic
*   **Tabel `products`:** `id` (PK), `name` (String), `category_id` (FK), `base_price` (Decimal), `base_unit` (String - contoh: 'gram', 'cm', 'pcs').
*   **Tabel `product_units` (Fleksibilitas Satuan):** `id` (PK), `product_id` (FK), `unit_name` (String - contoh: 'karung', 'dus', 'meter'), `conversion_multiplier` (Decimal - contoh: 25000 untuk konversi karung ke gram), `price_adjustment` (Decimal).
*   **Tabel `inventory`:** `product_id` (FK), `stock_quantity` (Wajib Decimal/Float, disimpan selalu dalam `base_unit` agar tidak ada nilai desimal yang hilang/dibulatkan).
*   **Tabel `transactions` & `transaction_details`:** Menyimpan *snapshot* `sold_price` (harga saat itu), `quantity`, dan `unit_used`.

## 7. Hardware & Peripheral Integration (Zero Client-Drivers)
Sistem harus *plug-and-play* tanpa kasir perlu menginstal *driver* apa pun di Tablet/HP mereka.

*   **Barcode Scanner Logic (Frontend):** 
    Scanner USB/Bluetooth bekerja sebagai *keyboard wedge*. *Frontend* SvelteKit wajib memiliki `Global Event Listener` di *background* yang mendeteksi rentetan ketikan berkecepatan tinggi (di bawah 50ms antar karakter) yang diakhiri `Enter`. Produk langsung masuk keranjang tanpa kasir harus mengarahkan kursor ke kolom pencarian. Sediakan juga *fallback* pemindai via kamera HTML5 untuk HP.
*   **Thermal Printer Logic (Backend ESC/POS):** 
    Jangan gunakan `window.print()` atau *pop-up browser*. Printer Thermal (USB/LAN) dicolokkan/terhubung langsung ke STB (Server). Saat kasir menekan tombol "Bayar" di Tablet, SvelteKit mengirim JSON transaksi ke Hono. *Backend* Hono menggunakan *library* **ESC/POS** untuk mengirim perintah *print raw* langsung ke *port* Linux di STB (misal `/dev/usb/lp0`). Hasilnya: Struk tercetak instan tanpa suara/pop-up di layar kasir.