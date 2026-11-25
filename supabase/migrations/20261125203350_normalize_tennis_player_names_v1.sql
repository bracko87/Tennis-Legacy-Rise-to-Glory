create or replace function control_center_private.normalize_tennis_player_names_v1()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  field_no integer;
  raw_name text;
  words text[];
  i integer;
  word text;
begin
  if new.player_type is distinct from 'human' then return new; end if;
  for field_no in 1..2 loop
    if field_no = 1 then
      if tg_op = 'UPDATE' then
        if new.first_name is not distinct from old.first_name then continue; end if;
      end if;
      raw_name := new.first_name;
    else
      if tg_op = 'UPDATE' then
        if new.last_name is not distinct from old.last_name then continue; end if;
      end if;
      raw_name := new.last_name;
    end if;
    if raw_name is null then continue; end if;
    words := pg_catalog.regexp_split_to_array(pg_catalog.btrim(raw_name), '[[:space:]]+');
    for i in 1..pg_catalog.cardinality(words) loop
      word := words[i];
      if field_no = 2 and i < pg_catalog.cardinality(words)
         and pg_catalog.lower(word) in ('da','das','de','del','della','den','der','di','do','dos','du','la','le','van','von','ten','ter','bin','ibn','al') then
        words[i] := pg_catalog.lower(word);
      elsif word ~ '^[[:alpha:]''’\-]+$'
        and (word = pg_catalog.lower(word)
          or (word = pg_catalog.upper(word) and pg_catalog.char_length(word) > 2)
          or word ~ '^[[:upper:]]{2}[[:lower:]]{2,}$') then
        words[i] := pg_catalog.initcap(word);
      end if;
    end loop;
    if field_no = 1 then new.first_name := pg_catalog.array_to_string(words,' ');
    else new.last_name := pg_catalog.array_to_string(words,' '); end if;
  end loop;
  return new;
end;
$fn$;
revoke all on function control_center_private.normalize_tennis_player_names_v1() from public, anon, authenticated;
create trigger zz_normalize_tennis_player_names_v1
before insert or update of first_name, last_name on public.players
for each row execute function control_center_private.normalize_tennis_player_names_v1();
