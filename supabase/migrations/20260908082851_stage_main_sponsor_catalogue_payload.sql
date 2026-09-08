create table public._main_sponsor_import_staging_20260908 (
  part_no integer primary key,
  payload text not null
);

revoke all on table public._main_sponsor_import_staging_20260908 from anon, authenticated;