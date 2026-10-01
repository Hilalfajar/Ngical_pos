-- ============================================================
-- Ngical - Bersihin baris "branches" yang dobel (kode sama,
-- store_id sama) SEBELUM bikin unique index.
-- Jalankan di: Supabase Dashboard -> SQL Editor -> New query
-- ============================================================

-- 1) Lihat dulu mana aja yang dobel (opsional, buat ngecek)
select store_id, kode, count(*) as jumlah, array_agg(id) as branch_ids, array_agg(nama) as nama_nama
from branches
where kode <> ''
group by store_id, kode
having count(*) > 1;

-- 2) Bersihin: buat tiap grup (store_id, kode) yang dobel,
--    pertahankan SATU baris (yang paling lama dibuat / ctid
--    terkecil), pindahin semua referensi transaksi & device
--    yang nunjuk ke baris dobel lainnya ke baris yang
--    dipertahankan, baru hapus baris dobelnya.
do $$
declare
  r record;
  keep_id uuid;
  dup_ids uuid[];
begin
  for r in
    select store_id, kode, array_agg(id order by ctid) as ids
    from branches
    where kode <> ''
    group by store_id, kode
    having count(*) > 1
  loop
    keep_id := r.ids[1];
    dup_ids := r.ids[2:array_length(r.ids, 1)];

    update transactions set branch_id = keep_id
      where branch_id = any(dup_ids);

    update devices set branch_id = keep_id
      where branch_id = any(dup_ids);

    delete from branches where id = any(dup_ids);
  end loop;
end $$;

-- 3) Sekarang baru bikin unique index-nya (ini yang kemarin gagal)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_branches_store_kode
  ON branches (store_id, kode)
  WHERE kode <> '';
