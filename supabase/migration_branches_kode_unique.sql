-- ============================================================
-- Ngical - Migrasi: cegah kode cabang dobel per toko
-- Jalankan di: Supabase Dashboard -> SQL Editor -> New query
-- Aman dijalankan di project yang sudah berjalan (idempotent).
--
-- Kenapa: sebelumnya "branches" cuma dicocokkan pakai local_id (ID
-- SQLite masing-masing device), jadi 2 device yang merepresentasikan
-- cabang yang sama bisa bikin baris branch dobel di cloud. App sisi
-- client sekarang sudah dibenerin buat cocokkan by "kode" dulu
-- (lihat ensureBranch di sync_service.dart) - index ini jadi jaring
-- pengaman terakhir di level database kalau ada race condition
-- (2 device push nyaris bersamaan).
--
-- Index PARSIAL (WHERE kode <> '') supaya cabang lama yang belum
-- punya kode (kode kosong) tidak ikut kena constraint ini.
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS uniq_branches_store_kode
  ON branches (store_id, kode)
  WHERE kode <> '';
