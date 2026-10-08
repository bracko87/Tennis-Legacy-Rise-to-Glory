-- Allow the new sixth Houses & Villas tier (Private Villa).
alter table public.private_life_asset_catalog
  drop constraint if exists private_life_asset_catalog_tier_check;

alter table public.private_life_asset_catalog
  add constraint private_life_asset_catalog_tier_check
  check (tier >= 1 and tier <= 6);
