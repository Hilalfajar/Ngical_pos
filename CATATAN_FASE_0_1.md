# Catatan Implementasi Fase 0 + 1

## Yang sudah dikerjakan di kode (Fase 1)

### File baru
| File | Fungsi |
|------|--------|
| `lib/config/supabase_config.dart` | Placeholder URL + anon key. Isi ini dulu sebelum tes multi-cabang. |
| `lib/services/sync_service.dart` | Singleton: generate owner_key, derive email/password, ensureAuth, ensureBranch, checkInDevice, completeOnboarding. |
| `lib/screens/onboarding.dart` | Layar "Buat Toko Baru" / "Gabung dengan Kunci Owner" / skip offline. |

### File diubah
| File | Perubahan |
|------|-----------|
| `lib/main.dart` | `Supabase.initialize()` + load SyncService prefs. Shell memutuskan Onboarding vs Home. |

### Alur yang sudah jalan
1. App start → init Supabase (kalau config sudah diisi) → load prefs sync.
2. Kalau `SupabaseConfig.isConfigured` **dan** belum ada `owner_key` di prefs → tampil **OnboardingPage**.
3. User pilih:
   - **Buat Toko Baru** → generate kunci 16 karakter (format `XXXX-XXXX-XXXX-XXXX`), input kode/nama cabang, tekan "Buat & Hubungkan".
   - **Gabung dengan Kunci Owner** → input kunci + kode cabang, pilih apakah device ini owner atau cabang.
   - **Nanti saja** → masuk Home seperti biasa (offline).
4. Di belakang layar: `signUp`/`signIn` pakai email sintetis → upsert `stores` → upsert `branches` by `(store_id, kode)` → upsert `devices`.

---

## Yang harus kamu lakukan manual (Fase 0)

1. Buka https://supabase.com → **New project**
2. Project Settings → API → salin:
   - **Project URL**
   - **anon public** key
3. Tempel ke `lib/config/supabase_config.dart`:
   ```dart
   static const String url = 'https://xxxx.supabase.co';
   static const String anonKey = 'eyJhbGciOi...';
   ```
4. SQL Editor → jalankan **berurutan**:
   1. `supabase/schema.sql`
   2. `supabase/migration_devices.sql`
   3. `supabase/migration_branch_profile.sql`
   4. `supabase/migration_branches_kode_unique.sql`
   - *(bandingkan dulu `migration_secure_rls.sql` — skip kalau isinya sudah di `schema.sql`)*
5. Authentication → Providers → Email → **matikan Confirm email** (wajib).
6. Hot restart / rebuild app → onboarding muncul.

---

## Cara tes cepat (setelah Fase 0 selesai)

| Device | Aksi |
|--------|------|
| Emulator / HP A | Buat Toko Baru → catat Kunci Owner → kode `PST` |
| HP B | Gabung dengan Kunci Owner → tempel kunci → kode `KRW1` |
| Supabase Dashboard → Table Editor | Cek tabel `stores`, `branches`, `devices` sudah terisi |

---

## Belum dikerjakan (Fase berikutnya)

- **Fase 2** sudah sebagian (ensureBranch + checkIn) — tinggal polish UI status cabang.
- **Fase 3** — kolom `synced` di SQLite + `pushPending()`.
- **Fase 4** — layar `laporan_owner.dart`.
- **Fase 5** — halaman status device online/offline.

Kalau Fase 0 sudah siap (URL + key + SQL jalan), bilang saja biar lanjut ke Fase 3 (push transaksi).
