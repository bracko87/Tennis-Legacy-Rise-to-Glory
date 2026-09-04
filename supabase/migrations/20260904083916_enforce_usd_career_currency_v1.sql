update public.player_career_finance_accounts set currency='USD' where currency is distinct from 'USD';
update public.career_finance_settings set currency='USD' where currency is distinct from 'USD';
update public.career_tax_settings set currency='USD' where currency is distinct from 'USD';

alter table public.player_career_finance_accounts
  drop constraint if exists player_career_finance_accounts_currency_usd_chk;
alter table public.player_career_finance_accounts
  add constraint player_career_finance_accounts_currency_usd_chk check (currency='USD');

alter table public.career_finance_settings
  drop constraint if exists career_finance_settings_currency_usd_chk;
alter table public.career_finance_settings
  add constraint career_finance_settings_currency_usd_chk check (currency='USD');

alter table public.career_tax_settings
  drop constraint if exists career_tax_settings_currency_usd_chk;
alter table public.career_tax_settings
  add constraint career_tax_settings_currency_usd_chk check (currency='USD');
