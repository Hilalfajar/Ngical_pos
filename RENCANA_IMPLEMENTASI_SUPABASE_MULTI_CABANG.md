# Rencana Implementasi Supabase Multi-Cabang — Ngical

Disusun setelah cek langsung isi zip `Ngical_posV1_29_offline_final_update_dari_1_27`. Jadi ini bukan rencana generik — udah disesuaikan sama kode & schema yang kamu punya sekarang.

---

## 1. Status project saat ini (hasil cek)

### Flutter app (`lib/`)

- **100% offline.** Satu file SQLite (`warung_db.db`) per device, dikelola `Db` singleton di `lib/data/db.dart`.
- Tabel lokal: `produk`, `transaksi`, `transaksi_item`, `bahan`, `resep_item`, `staff`, `produk_tier`, `stok_update`, `stok_update_item`.
- Tidak ada konsep cabang/branch/owner-key di kode Flutter sama sekali — `storeName`/`ownerName` di `app.dart` cuma profil buat cetak struk, bukan identitas multi-tenant.
- `supabase_flutter: ^2.8.4` sudah ada di `pubspec.yaml` tapi belum dipakai di mana pun — `Supabase.initialize()` belum dipanggil, tidak ada `sync_service.dart`.

### Folder `supabase/` (schema yang udah kamu siapkan duluan)

- `schema.sql` — stores, branches, transactions, transaction_items, RLS by `owner_user_id = auth.uid()`.
- `migration_devices.sql` — tabel devices buat status online/offline tiap device.
- `migration_branch_profile.sql` — kolom alamat/telepon/QRIS per cabang.
- `migration_branches_kode_unique.sql` — cegah cabang dobel, matching by kode.
- `migration_secure_rls.sql` — versi RLS yang lebih ketat (kemungkinan superseded oleh yang di `schema.sql`, cek dobel sebelum run).

**Kesimpulan:** desain database cloud-nya udah cukup matang dan sudah cocok sama arah yang kita obrolin (transaksi dari semua cabang bisa dibaca owner). Yang belum ada sama sekali adalah kode Flutter yang menghubungkannya. Dokumen ini fokus ke situ.

---

## 2. Model akses — penting, putuskan dulu sebelum ngoding

Schema yang sudah ada pakai **1 owner_key per toko**. Semua device (owner maupun tiap cabang) login pakai email sintetis yang di-generate dari `owner_key` yang sama → semuanya jadi `auth.uid()` yang sama → RLS-nya cuma isolasi antar toko, bukan isolasi kasir vs owner dalam 1 toko.

Artinya: setiap device yang punya `owner_key` bisa baca/tulis semua data toko, termasuk transaksi cabang lain. Ini beda dari role-based RLS (kasir dibatasi cabang sendiri) yang sempat kita bahas di awal.

Ini bukan salah — buat kebutuhanmu ("owner bisa baca laporan semua cabang"), ini malah lebih simpel dan cukup. Tapi konsekuensinya: kalau `owner_key` bocor ke kasir yang nggak dipercaya, dia bisa lihat/ubah data cabang lain juga. Putuskan salah satu:

| Opsi | Deskripsi | Kelebihan | Kekurangan |
|------|-----------|-----------|------------|
| **A** (ikuti schema yang sudah ada) | 1 kunci buat semua device | Simpel, cepat kelar. Cocok kalau kasir semua orang kepercayaan / keluarga. | Kalau kunci bocor, akses penuh ke semua cabang |
| **B** (role-based, lebih rumit) | Kasir dapat kunci/login terpisah yang di-scope RLS ke `branch_id`-nya doang, owner dapat kunci beda yang bisa baca semua | Isolasi lebih ketat | Butuh redesign auth + RLS dari nol |

**Rekomendasi:** mulai dari **Opsi A** dulu (sesuai schema existing, cepat jalan), Opsi B belakangan kalau memang kebutuhannya muncul.

---

## 3. Fase implementasi

### Fase 0 — Setup Supabase

- Buat project Supabase, catat URL + anon key
- Jalankan berurutan:
  1. `schema.sql`
  2. `migration_devices.sql`
  3. `migration_branch_profile.sql`
  4. `migration_branches_kode_unique.sql`
  - *(skip `migration_secure_rls.sql` kalau isinya sudah ke-cover `schema.sql` — bandingkan dulu)*
- Authentication → Providers → Email → **matikan "Confirm email"** (wajib, karena app pakai email sintetis yang gak bisa terima link konfirmasi)

### Fase 1 — Wiring dasar di Flutter

- `Supabase.initialize(url:, anonKey:)` di `main.dart`, sebelum `runApp`
- Buat `lib/services/sync_service.dart`, pola singleton sama kayak `Db.i`
- Layar onboarding baru:
  - **"Buat Toko Baru"** → generate `owner_key` acak, tampilkan biar diketik manual ke device cabang
  - **"Gabung dengan Kunci Owner"** → input kunci yang sudah ada
- `_ensureAuth(ownerKey)`:
  - Turunkan email sintetis + password dari `owner_key` (misal hash)
  - `signUp` kalau belum ada / `signIn` kalau sudah
  - Dapat `auth.uid()`, lalu upsert row `stores` (`owner_user_id = auth.uid()`)
- Simpan `ownerKey`, `storeId`, `deviceId` (pakai `device_info_plus`, sudah ada di pubspec) ke `shared_preferences`

### Fase 2 — Registrasi cabang & device

- Saat onboarding, minta input **"Kode Cabang"** (misal `PST`, `KRW1`) + nama cabang
- `ensureBranch()`: upsert ke `branches` by `(store_id, kode)` — sesuai catatan di `migration_branches_kode_unique.sql`, **JANGAN** cuma andelin `local_id`
- Check-in ke tabel `devices` (`device_type`: owner/cabang, `branch_id`, `label`) tiap kali sync jalan → update `last_seen_at`

### Fase 3 — Push transaksi (offline-first, sesuai pola yang udah kamu jalanin)

- Migration lokal: `db.dart` versi **11** → tambah kolom `synced INTEGER NOT NULL DEFAULT 0` ke tabel `transaksi`
- Tiap transaksi baru dari `catatTransaksi()` otomatis `synced = 0`
- `SyncService.pushPending()`:
  - Ambil transaksi + transaksi_item `WHERE synced=0`
  - Upsert ke Supabase pakai unique key `(store_id, device_id, local_id)`
  - Sukses → set `synced=1` lokal
- Trigger push di 3 tempat:
  1. Begitu app start (setelah cek backup terjadwal)
  2. `workmanager` buat retry berkala di background (sudah ada di pubspec, belum dipakai buat ini)
  3. Listener connectivity biar langsung nyoba pas online lagi

### Fase 4 — Laporan lintas cabang (punya Owner)

- Layar baru, misal `lib/screens/laporan_owner.dart`
- Query langsung online ke Supabase (`select` dari `transactions`, filter `store_id` + rentang tanggal, group by `branch_id`/`cabang_nama`)
  - Tidak perlu disimpan balik ke SQLite lokal, karena sifatnya "lihat aja" bukan dipakai transaksi
- Pull-to-refresh buat re-query
- **(Opsional)** kalau owner butuh tetap lihat angka pas offline: simpan snapshot ringkas (total per cabang per hari) di `shared_preferences`, bukan raw data — biar gak berat & gak stale-looking kalau ditampilkan sebagai data real-time

### Fase 5 — Halaman status cabang (opsional, tapi kepake)

- List dari tabel `devices`
- Badge online/offline dihitung di app dari `last_seen_at` (misal `< 15 menit = online`)
  - Sesuai catatan di `migration_devices.sql`, **jangan** bikin kolom status terpisah

---

## 4. Yang BELUM ada di schema — jangan mulai dulu sebelum Fase 1–5 jalan

Schema saat ini cuma nyeritain transaksi, belum ada tabel buat produk/stok. Kalau nanti kamu mau:

- Owner update harga dari HP → otomatis ke-push ke semua cabang, atau
- Device cabang baru auto-keisi katalog produk tanpa input manual satu-satu,

...itu perlu tabel baru (`products`, mungkin `branch_stock` kalau stok per-cabang beda), + kolom `updated_at` buat sync incremental. Device baru pull full sekali di awal (karena produk itu master data, beda sifat sama log transaksi yang cuma perlu "hari ini").

**Catat ini sebagai Fase 6**, kerjain setelah alur transaksi + laporan di atas udah stabil dan kepake beneran — biar gak kebanyakan yang dikerjain sekaligus.

---

## 5. Urutan kerja yang disarankan

```
Fase 0 → 1 → 2 → 3 → 4 → 5
```

Tes end-to-end pakai **2 device** (misal emulator jadi "cabang", HP jadi "owner") tiap kelar 1 fase — jangan nunggu semua kelar baru dites.

**Fase 6** nyusul belakangan kalau memang kebutuhannya udah nyata.
