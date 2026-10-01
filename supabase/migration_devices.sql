-- ============================================================
-- Ngical - Migrasi: registry device (status koneksi Owner <-> Cabang)
-- Jalankan di: Supabase Dashboard -> SQL Editor -> New query
-- Aman dijalankan di project yang sudah berjalan (idempotent).
--
-- Tujuan: sebelum ini, "Terhubung ke Owner" cuma klaim sepihak dari
-- device cabang (dia PUNYA kunci owner yang benar), tapi Owner tidak
-- pernah tahu device mana saja yang benar-benar sudah connect & masih
-- aktif. Tabel ini jadi "buku tamu" tempat tiap device check-in ke
-- server tiap kali sync, supaya Owner bisa lihat daftar real + status
-- online/offline (berdasarkan kapan terakhir check-in).
-- ============================================================

CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_type TEXT NOT NULL DEFAULT 'cabang', -- 'owner' | 'cabang'
  branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
  branch_nama TEXT NOT NULL DEFAULT '',
  device_label TEXT NOT NULL DEFAULT '',
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(store_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_devices_store ON devices(store_id);

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "devices_owner_only" ON devices
  FOR ALL
  USING (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()));

-- Catatan:
-- - "device_type" & "branch_nama"/"device_label" dikirim device itu
--   sendiri saat check-in, murni informasi tampilan buat Owner.
-- - Status online/offline DIHITUNG DI APP dari last_seen_at (bukan
--   kolom terpisah), misal: online jika last_seen_at < 15 menit lalu.
-- - Sengaja pakai kolom biasa (bukan Realtime) supaya tetap ringan
--   dan konsisten dengan pola offline-first: Owner tinggal pull ulang
--   tabel ini tiap buka halaman Cabang / tarik ke bawah.
