# Rencana Mode Online / Offline - Ngical POS

## Mode Offline

- Buka app langsung masuk, tidak perlu login
- Semua data pakai SQLite di device
- Tidak butuh internet

## Mode Online

- Login dulu dengan email + password
- Semua data langsung baca/tulis ke Supabase
- Real-time, bisa di banyak HP sekaligus
- Butuh internet

---

## Pertanyaan yang belum diputuskan

### 1. Data offline mau dibawa ke online atau tidak?

Misal sudah pakai offline 1 bulan, ada 500 produk dan 1000 transaksi di SQLite.
Terus memutuskan mau beralih ke online.

Pilihan:
- **Migrasi** - data lama di SQLite di-upload ke Supabase dulu, baru lanjut pakai online
- **Mulai fresh** - data online kosong, data lama tetap ada di offline tapi tidak nyambung

### 2. Kalau sudah online lalu internet mati di tengah transaksi?

Pilihan:
- **Strict online** - transaksi gagal kalau tidak ada internet (seperti Tokopedia)
- **Hybrid** - simpan lokal dulu kalau offline, sync otomatis kalau internet nyala lagi

---

## Status

- [ ] Putuskan pertanyaan di atas
- [ ] Implementasi sistem auth email + password
- [ ] Implementasi mode online (Supabase)
- [ ] Implementasi mode offline (SQLite)
- [ ] Migrasi data (jika dipilih)
