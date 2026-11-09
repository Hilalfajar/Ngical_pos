# Ngical POS — Aplikasi Kasir Offline

> Aplikasi kasir modern untuk Android & Windows yang bekerja sepenuhnya **offline** tanpa koneksi internet.

---

## Daftar Isi

- [Tentang Aplikasi](#tentang-aplikasi)
- [Fitur Utama](#fitur-utama)
- [Platform yang Didukung](#platform-yang-didukung)
- [Teknologi](#teknologi)
- [Struktur Project](#struktur-project)
- [Cara Menjalankan](#cara-menjalankan)
- [Database](#database)
- [Backup & Restore](#backup--restore)

---

## Tentang Aplikasi

**Ngical POS** adalah aplikasi Point of Sale (POS) / kasir yang dirancang untuk usaha kecil dan menengah seperti warung, toko sembako, kafe kecil, dan sejenisnya. Semua data tersimpan secara lokal di perangkat — tidak memerlukan server atau koneksi internet untuk beroperasi.

Versi: **1.1.36**

---

## Fitur Utama

### 🛒 Kasir (POS)
- Tambah produk ke keranjang dengan tap atau scan barcode
- Scan barcode via kamera (Android/iOS)
- Hitung kembalian otomatis
- Dukungan metode pembayaran: **Cash**, **QRIS**, **Transfer Bank**, **Hutang**
- QRIS dinamis — nominal otomatis tertanam di QR sesuai total belanja (standar BI EMV QCPM)
- Edit atau batalkan transaksi yang sudah masuk
- Kelola tagihan hutang pelanggan dan tandai lunas

### 📦 Produk
- Tambah, edit, dan hapus produk
- Upload foto produk (dari galeri, kamera, atau URL/Google Drive)
- Scan barcode langsung dari form produk
- Kelompokkan produk per **kategori**
- Atur **harga paket / grosir** (contoh: beli 3 = Rp10.000)
- Manajemen stok produk

### 📊 Update Stok
- Tambah stok produk secara massal (batch)
- Riwayat setiap sesi update stok tersimpan lengkap dengan detail item

### 📈 Laporan
- Laporan penjualan harian, mingguan, bulanan
- Grafik pendapatan (fl_chart)
- Ringkasan: total pendapatan, total modal, laba bersih
- Daftar riwayat transaksi lengkap dengan detail item
- Export laporan ke **Excel (.xlsx)** dan **CSV**

### 🖨️ Cetak Struk
- Dukungan printer **Bluetooth** (thermal)
- Dukungan printer **WiFi / LAN** (raw TCP port 9100)
- Cetak via **sistem Windows** (dialog print atau printer langsung tanpa dialog)
- Atur lebar kertas: 58mm / 80mm
- Opsional: cetak logo toko dan footer di struk

### ⚙️ Pengaturan Toko
- Nama toko, alamat, nomor telepon, nama pemilik
- Logo toko untuk struk
- Konfigurasi QRIS (token), rekening bank transfer
- Semua pengaturan tersimpan di SharedPreferences

### 💾 Backup & Restore
- Backup data ke file **JSON** (full: produk + transaksi, atau produk saja)
- Restore dari file backup JSON
- Import produk dari file **CSV**
- Jadwal backup otomatis (harian / mingguan) dengan pemilihan jam
- Backup berjalan di background saat app ditutup/diminimize

---

## Platform yang Didukung

| Platform  | Status        |
|-----------|---------------|
| Android   | ✅ Didukung   |
| Windows   | ✅ Didukung   |
| iOS       | 🔧 Tersedia   |
| macOS     | 🔧 Tersedia   |
| Linux     | 🔧 Tersedia   |
| Web       | 🔧 Tersedia   |

---

## Teknologi

| Paket | Kegunaan |
|---|---|
| `flutter` + `provider` | Framework UI + state management |
| `sqflite` + `sqflite_common_ffi` | Database lokal SQLite (Android & Desktop) |
| `shared_preferences` | Simpan pengaturan |
| `mobile_scanner` | Scan barcode via kamera |
| `print_bluetooth_thermal` + `esc_pos_utils_plus` | Cetak struk Bluetooth |
| `pdf` + `printing` | Cetak struk PDF (Windows/sistem) |
| `fl_chart` | Grafik laporan |
| `excel` | Export laporan ke Excel |
| `qr_flutter` | Generate QR code QRIS |
| `file_picker` + `share_plus` | Pilih file & share/export |
| `image_picker` | Ambil foto produk |
| `archive` | Kompresi file backup |

---

## Struktur Project

```
lib/
├── main.dart              # Entry point aplikasi
├── theme.dart             # Tema warna & style global
├── data/
│   └── db.dart            # Database SQLite (semua tabel & query)
├── models/
│   └── models.dart        # Data class: Produk, Transaksi, dll
├── providers/
│   └── app.dart           # State management (ChangeNotifier)
├── screens/
│   ├── home.dart          # Shell utama + routing antar halaman
│   ├── kasir.dart         # Halaman POS / kasir
│   ├── produk.dart        # Manajemen produk & stok
│   ├── laporan.dart       # Laporan & riwayat transaksi
│   ├── update_stok.dart   # Sesi update stok massal
│   ├── printer.dart       # Pengaturan & tes printer
│   └── simple.dart        # Pengaturan toko, backup, about
├── services/
│   ├── printer_service.dart  # Logic cetak struk (BT/WiFi/Windows)
│   ├── report_service.dart   # Generate laporan & export
│   └── backup_service.dart   # Backup & restore data
├── utils/
│   ├── formatter.dart     # Format angka, tanggal, satuan
│   ├── qris_dynamic.dart  # Konversi QRIS static → dynamic (EMV QCPM)
│   └── toast.dart         # Notifikasi toast UI
└── widgets/
    └── bottom_nav.dart    # Navigasi bawah (mobile)
```

---

## Cara Menjalankan

### Prasyarat
- Flutter SDK `>=3.2.0`
- Dart SDK `>=3.2.0`

### Instalasi

```bash
# Clone project
git clone <url-repo>
cd Ngical_pos_offline

# Install dependencies
flutter pub get

# Jalankan di Windows
flutter run -d windows

# Jalankan di Android (pastikan emulator/device terhubung)
flutter run -d android

# Build APK release
flutter build apk --release

# Build Windows release
flutter build windows --release
```

---

## Database

Aplikasi menggunakan **SQLite** via `sqflite`. Database tersimpan di direktori aplikasi secara lokal.

**Versi DB saat ini: 11**

Tabel yang digunakan:

| Tabel | Isi |
|---|---|
| `produk` | Data produk (nama, harga, stok, barcode, kategori, foto) |
| `transaksi` | Header transaksi penjualan |
| `transaksi_item` | Detail item per transaksi |
| `produk_tier` | Harga paket / grosir per produk |
| `stok_update` | Riwayat sesi update stok |
| `stok_update_item` | Detail item per sesi update stok |

Migrasi DB dilakukan otomatis via `onUpgrade` saat versi DB naik. Khusus versi
12, tabel `staff` di-`DROP` karena fitur akun staff sudah dihapus dari app;
tabel lain tidak disentuh.

---

## Backup & Restore

File backup berformat **JSON** dengan struktur:

```json
{
  "version": 2,
  "type": "full",
  "timestamp": 1234567890000,
  "settings": { ... },
  "produks": [ ... ],
  "transaksis": [ ... ],
  "transaksiItems": [ ... ]
}
```

- **Full backup** — produk + seluruh riwayat transaksi + pengaturan toko
- **Produk only** — hanya data produk (cocok untuk pindah device / reset toko)
- Import CSV — format: `ID, Nama, Barcode, Harga Modal, Harga Jual, Stok, Satuan, Foto`

---

## Lisensi

Project ini dibuat untuk keperluan internal / komersial. Silakan hubungi pengembang untuk informasi lebih lanjut.
