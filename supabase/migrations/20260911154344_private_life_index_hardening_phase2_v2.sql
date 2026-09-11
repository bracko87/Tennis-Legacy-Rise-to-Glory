create index if not exists private_life_player_assets_catalog_code_idx
  on public.private_life_player_assets(catalog_code);

create index if not exists private_life_player_assets_purchase_tx_idx
  on public.private_life_player_assets(purchase_transaction_id)
  where purchase_transaction_id is not null;

create index if not exists private_life_player_assets_sale_tx_idx
  on public.private_life_player_assets(sale_transaction_id)
  where sale_transaction_id is not null;

create index if not exists private_life_asset_events_finance_tx_idx
  on public.private_life_asset_events(finance_transaction_id)
  where finance_transaction_id is not null;
