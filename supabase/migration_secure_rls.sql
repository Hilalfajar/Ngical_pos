-- ============================================================
-- Ngical - Migrasi keamanan: isolasi data per toko (multi-tenant)
-- Jalankan di: Supabase Dashboard -> SQL Editor -> New query
-- Aman dijalankan di project yang sudah berjalan (idempotent).
-- ============================================================

-- 1) Kolom baru: pemilik toko diikat ke user Supabase Auth,
--    bukan cuma teks owner_key yang bisa diklaim siapa saja.
ALTER TABLE stores ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES auth.users(id);

-- 2) Hapus policy lama yang membuka semua baris ke siapapun.
DROP POLICY IF EXISTS "anon_all_stores" ON stores;
DROP POLICY IF EXISTS "anon_all_branches" ON branches;
DROP POLICY IF EXISTS "anon_all_trx" ON transactions;
DROP POLICY IF EXISTS "anon_all_items" ON transaction_items;

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;

-- 3) Policy baru: hanya user auth yang owner_user_id-nya cocok
--    yang boleh baca/tulis baris toko itu. Baris tanpa sesi login
--    (anon murni) otomatis ditolak karena auth.uid() = NULL.

CREATE POLICY "stores_owner_only" ON stores
  FOR ALL
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "branches_owner_only" ON branches
  FOR ALL
  USING (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()));

CREATE POLICY "transactions_owner_only" ON transactions
  FOR ALL
  USING (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_user_id = auth.uid()));

CREATE POLICY "transaction_items_owner_only" ON transaction_items
  FOR ALL
  USING (
    transaction_id IN (
      SELECT t.id FROM transactions t
      JOIN stores s ON s.id = t.store_id
      WHERE s.owner_user_id = auth.uid()
    )
  )
  WITH CHECK (
    transaction_id IN (
      SELECT t.id FROM transactions t
      JOIN stores s ON s.id = t.store_id
      WHERE s.owner_user_id = auth.uid()
    )
  );

-- ============================================================
-- PENTING - langkah manual satu kali di dashboard (bukan di SQL):
-- Authentication -> Sign In / Providers -> Email
-- -> matikan toggle "Confirm email"
--
-- Ini WAJIB karena aplikasi membuat email sintetis (bukan email asli
-- pembeli) untuk tiap toko secara otomatis di belakang layar, dan
-- email itu tidak bisa menerima link konfirmasi. Kalau toggle ini
-- tidak dimatikan, proses login otomatis akan gagal terus.
-- ============================================================

-- Catatan data lama:
-- Baris "stores" yang sudah ada sebelum migrasi ini owner_user_id-nya
-- masih NULL, sehingga jadi tidak bisa diakses siapapun (termasuk
-- pemiliknya sendiri) sampai toko itu sync ulang (otomatis akan
-- membuat sesi auth baru dan mengisi owner_user_id lewat app terbaru).
