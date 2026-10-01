-- 1) Harusnya 0 baris sekarang (duplikat sudah dibersihkan)
select store_id, kode, count(*) as jumlah
from branches
where kode <> ''
group by store_id, kode
having count(*) > 1;

-- 2) Harusnya muncul 1 baris "uniq_branches_store_kode" (index berhasil dibuat)
select indexname, indexdef
from pg_indexes
where tablename = 'branches'
  and indexname = 'uniq_branches_store_kode';
