-- ============================================================
-- NGICAL POS — Supabase Schema (Full Online, 1 Toko)
-- Jalankan seluruh file ini di Supabase SQL Editor (satu kali)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- AUTH
-- Toko login dengan email + password biasa via Supabase Auth.
-- Login bisa pakai email ATAU username.
-- Semua tabel dilindungi RLS: hanya auth user yang login bisa akses.
-- ============================================================

-- ── PROFILES (username per user) ────────────────────────────
-- Otomatis dibuat saat user daftar via trigger.
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  created_at    timestamptz default now()
);

alter table profiles enable row level security;

-- Siapapun bisa baca username (untuk lookup saat login)
create policy "profiles: baca publik"
  on profiles for select
  using (true);

-- Hanya user sendiri yang bisa update profilnya
create policy "profiles: update sendiri"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Insert diizinkan saat daftar (via service role di trigger)
create policy "profiles: insert sendiri"
  on profiles for insert
  with check (auth.uid() = id);

-- Index untuk pencarian username cepat (case-insensitive)
create index if not exists idx_profiles_username_lower
  on profiles (lower(username));

-- ============================================================
-- AUTH
-- Toko login dengan email + password biasa via Supabase Auth.
-- Semua tabel dilindungi RLS: hanya auth user yang login bisa akses.
-- ============================================================

-- ── PRODUK ──────────────────────────────────────────────────
create table if not exists produk (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  nama          text not null,
  satuan        text not null default 'pcs',
  barcode       text,
  harga_modal   integer not null default 0,
  harga         integer not null,
  stok          double precision not null default 0,
  foto_url      text,
  kategori      text,
  gunakan_hpp   boolean not null default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table produk enable row level security;
create policy "produk: akses sendiri" on produk
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── BAHAN ────────────────────────────────────────────────────
create table if not exists bahan (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  nama          text not null,
  satuan        text not null default 'g',
  harga_beli    integer not null default 0,
  jumlah_beli   double precision not null default 1,
  stok          double precision not null default 0,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table bahan enable row level security;
create policy "bahan: akses sendiri" on bahan
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── RESEP ITEM ───────────────────────────────────────────────
create table if not exists resep_item (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  produk_id     uuid not null references produk(id) on delete cascade,
  bahan_id      uuid not null references bahan(id) on delete cascade,
  qty           double precision not null
);

alter table resep_item enable row level security;
create policy "resep_item: akses sendiri" on resep_item
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── PRODUK TIER (harga paket/grosir) ────────────────────────
create table if not exists produk_tier (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  produk_id     uuid not null references produk(id) on delete cascade,
  min_qty       double precision not null,
  harga         integer not null,
  label         text not null default ''
);

alter table produk_tier enable row level security;
create policy "produk_tier: akses sendiri" on produk_tier
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── STAFF ────────────────────────────────────────────────────
create table if not exists staff (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  nama          text not null,
  pin           text not null,
  role          text not null default 'Kasir',
  aktif         boolean not null default true,
  permissions   text not null default '',
  created_at    timestamptz default now()
);

alter table staff enable row level security;
create policy "staff: akses sendiri" on staff
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── TRANSAKSI ────────────────────────────────────────────────
create table if not exists transaksi (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  tanggal       bigint not null,
  total_belanja integer not null,
  total_bayar   integer not null,
  kembalian     integer not null,
  no_urut       integer not null default 0,
  metode        text not null default 'cash',
  status        text not null default 'selesai',
  nama_hutang   text not null default '',
  created_at    timestamptz default now()
);

alter table transaksi enable row level security;
create policy "transaksi: akses sendiri" on transaksi
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_transaksi_tanggal on transaksi(user_id, tanggal desc);

-- ── TRANSAKSI ITEM ───────────────────────────────────────────
create table if not exists transaksi_item (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  transaksi_id  uuid not null references transaksi(id) on delete cascade,
  produk_id     uuid not null,
  nama_produk   text not null,
  harga_modal   integer not null default 0,
  harga_satuan  integer not null,
  jumlah        double precision not null,
  subtotal      integer not null
);

alter table transaksi_item enable row level security;
create policy "transaksi_item: akses sendiri" on transaksi_item
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_transaksi_item_trx on transaksi_item(transaksi_id);

-- ── STOK UPDATE ──────────────────────────────────────────────
create table if not exists stok_update (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  tanggal       bigint not null,
  no_urut       integer not null,
  total_item    integer not null,
  total_qty     double precision not null
);

alter table stok_update enable row level security;
create policy "stok_update: akses sendiri" on stok_update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── STOK UPDATE ITEM ─────────────────────────────────────────
create table if not exists stok_update_item (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  update_id     uuid not null references stok_update(id) on delete cascade,
  produk_id     uuid not null,
  nama_produk   text not null,
  qty           double precision not null,
  stok_sebelum  double precision not null,
  stok_sesudah  double precision not null
);

alter table stok_update_item enable row level security;
create policy "stok_update_item: akses sendiri" on stok_update_item
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- FUNGSI updated_at otomatis
-- ============================================================
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_produk_updated_at
  before update on produk
  for each row execute function update_updated_at();

create trigger trg_bahan_updated_at
  before update on bahan
  for each row execute function update_updated_at();

-- ============================================================
-- REALTIME — aktifkan publication untuk semua tabel
-- ============================================================
alter publication supabase_realtime add table produk;
alter publication supabase_realtime add table bahan;
alter publication supabase_realtime add table resep_item;
alter publication supabase_realtime add table produk_tier;
alter publication supabase_realtime add table staff;
alter publication supabase_realtime add table transaksi;
alter publication supabase_realtime add table transaksi_item;
alter publication supabase_realtime add table stok_update;
alter publication supabase_realtime add table stok_update_item;

-- ============================================================
-- STORAGE BUCKET untuk foto produk
-- ============================================================

-- Buat bucket "produk-foto" yang public (bisa dibaca semua orang dengan URL)
insert into storage.buckets (id, name, public)
values ('produk-foto', 'produk-foto', true)
on conflict (id) do nothing;

-- Policy: hanya user yang login bisa upload/update/delete foto miliknya
create policy "produk-foto: upload sendiri"
  on storage.objects for insert
  with check (
    bucket_id = 'produk-foto' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "produk-foto: update sendiri"
  on storage.objects for update
  using (
    bucket_id = 'produk-foto' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "produk-foto: delete sendiri"
  on storage.objects for delete
  using (
    bucket_id = 'produk-foto' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: semua orang bisa baca (public bucket)
create policy "produk-foto: baca publik"
  on storage.objects for select
  using (bucket_id = 'produk-foto');

-- ============================================================
-- CATATAN PENTING SETELAH MENJALANKAN SCHEMA INI:
-- 1. Di Supabase Dashboard -> Authentication -> Providers -> Email:
--    AKTIFKAN "Confirm email" (toggle ON).
--    User perlu klik link verifikasi di email sebelum bisa login.
-- 2. Di Supabase Dashboard -> Realtime -> pastikan Realtime sudah Enable.
-- 3. Auth menggunakan email + password biasa.
--    User daftar dan login langsung lewat form di app.
-- ============================================================
