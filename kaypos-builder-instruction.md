# 🚀 KAYPOS Architecture & Builder Documentation

Dokumen ini menjelaskan alur (perjalanan) sistem KAYPOS dari Frontend hingga Backend, serta memuat panduan lengkap tentang konfigurasi infrastruktur CI/CD (GitHub Actions) yang memungkinkan proses kompilasi aplikasi privat secara gratis melalui repositori publik.

---

## 🏗️ 1. Perjalanan Aplikasi: Frontend ke Backend

KAYPOS adalah aplikasi Point of Sale modern yang mengusung arsitektur **Client-Server** yang ringan dan tangguh.

### A. Frontend (Flutter)
Berfungsi sebagai antarmuka kasir utama yang berinteraksi langsung dengan pengguna.
* **Multi-Platform:** Dibangun menggunakan Flutter sehingga dapat dijalankan di Android (.apk), Windows (.exe), dan Linux (.deb / .rpm).
* **Fitur Utama:**
  * Manajemen keranjang belanja dan transaksi kasir.
  * Modul riwayat transaksi.
  * Fitur pencetakan struk thermal.
  * Auto-updater mandiri.
* **Sistem Pencetakan Struk (Print):** 
  Logika pencetakan struk (ESC/POS) ditangani 100% di Frontend menggunakan library `esc_pos_utils_plus`. Frontend membaca pengaturan (Store Name, Address, dll) dari API Backend, kemudian merakit *raw bytes* untuk dikirim langsung ke printer Bluetooth/USB melalui perangkat kasir.

### B. Backend (Node.js + Hono + SQLite)
Berfungsi sebagai otak dan pusat penyimpanan data lokal.
* **Server Ringan:** Dibangun menggunakan framework Hono (Edge-ready) di atas environment Node.js. Server berjalan secara lokal di komputer toko.
* **Database (SQLite):** Menggunakan SQLite yang cepat dan tidak butuh instalasi rumit, menyimpan produk, unit, stok (inventory), transaksi, dan pengaturan toko.
* **REST API:** Frontend (aplikasi kasir di HP Android atau Desktop) memanggil REST API ke Backend (misalnya `GET /products`, `POST /transactions`, `GET /settings`) melalui jaringan lokal (LAN/WiFi).

### C. Alur Kerja (Workflow)
1. Aplikasi kasir (Frontend) meminta IP Server saat login.
2. Kasir memindai barang -> Frontend melakukan request harga & stok ke Backend.
3. Kasir menekan "Bayar" -> Frontend mengirim data POST transaksi ke Backend.
4. Backend menyimpan ke SQLite.
5. Frontend memanggil generator ESC/POS -> Mengirim struk langsung ke Printer Thermal kasir.

---

## ♾️ 2. Infrastruktur CI/CD: Private Source ke Public Builder

Karena keterbatasan menit gratis (quota) untuk menjalankan GitHub Actions di Repositori Privat, KAYPOS menggunakan trik **"Remote Public Builder"**.

* **Private Repo (`babycodes/KAYPOS-FLUTTER`):** Tempat penyimpanan *source code* yang dirahasiakan (Aman).
* **Public Repo (`babycodes/KAYPOS-APP`):** Repositori kosong (publik) yang difungsikan **hanya** sebagai mesin pabrik (Runner) untuk melakukan *build* tanpa batasan menit dari GitHub.

### Alur Update Otomatis:
1. Developer melakukan `git push` ke **Private Repo**.
2. Developer men-trigger GitHub Actions di **Public Repo**.
3. Action di Public Repo diam-diam mengambil source code dari Private Repo menggunakan *Personal Access Token (PAT)*.
4. Action melakukan build (APK, EXE, DEB, RPM) dan menyematkan sertifikat Keystore (Android).
5. Hasil *build* mentah di-upload ke halaman **Releases** di Public Repo.
6. Aplikasi KAYPOS Frontend mengecek API publik GitHub dan mendownload update secara otomatis jika versi baru tersedia.

---

## 🛠️ 3. Step-by-Step Setup "Remote Builder" GitHub Actions

Ikuti panduan ini jika kamu perlu men-setup ulang CI/CD dari awal.

### Langkah 1: Buat Token Akses (PAT)
1. Buka GitHub -> Settings (Profil) -> **Developer Settings** -> **Personal access tokens** -> **Tokens (classic)**.
2. Klik **Generate new token (classic)**.
3. Beri nama token (misal: `Kaypos_Builder`).
4. Centang kotak utama **`repo`** (Full control of private repositories).
5. Klik **Generate** dan **COPY** kode token tersebut (`ghp_...`).

### Langkah 2: Siapkan Base64 Keystore (Khusus Android)
Di terminal Linux/Mac (jalankan di folder project):
```bash
base64 -w 0 frontend/android/app/upload-keystore.jks
```
*Copy semua output teks panjang yang dihasilkan.*

### Langkah 3: Konfigurasi Secrets di Public Repo
Buka repositori publikmu (`babycodes/KAYPOS-APP`) -> **Settings** -> **Secrets and variables** -> **Actions**. 
Tambahkan 5 data rahasia berikut (klik *New repository secret*):

| Name | Secret Value |
| :--- | :--- |
| `PRIVATE_REPO_TOKEN` | Kode PAT dari Langkah 1 (`ghp_...`) |
| `KEYSTORE_BASE64` | Teks panjang Base64 dari Langkah 2 |
| `STORE_PASSWORD` | Password keystore kamu (misal: `QuieT@0101s`) |
| `KEY_PASSWORD` | Password keystore kamu (misal: `QuieT@0101s`) |
| `KEY_ALIAS` | Alias keystore kamu (misal: `QuieT@0101s__`) |

### Langkah 4: Tambahkan Script GitHub Actions
Di dalam repositori publik (`KAYPOS-APP`), buat file di direktori `.github/workflows/build.yml` dengan script remote builder yang menarik kode dari `babycodes/KAYPOS-FLUTTER` (Script telah dikonfigurasi pada panduan sebelumnya).

### Langkah 5: Cara Menjalankan Build
Setiap kali kamu selesai membuat perubahan di kode aplikasi dan ingin membuat APK/EXE versi terbaru:
1. Pastikan nomor versi di `pubspec.yaml` (repo privat) sudah dinaikkan (misal: `1.0.16`).
2. Lakukan `git push` pada repo privat (`KAYPOS-FLUTTER`).
3. Buka repositori **KAYPOS-APP** (repo publik) di browser.
4. Klik tab **Actions**.
5. Klik pada workflow **Remote Cross-Platform Builder** di sebelah kiri.
6. Klik tombol **Run workflow** -> masukkan branch (`main`) -> klik **Run workflow**.
7. Tunggu sekitar 15-20 menit. Saat selesai, file update akan otomatis muncul di menu **Releases** repo publik! 🎊
