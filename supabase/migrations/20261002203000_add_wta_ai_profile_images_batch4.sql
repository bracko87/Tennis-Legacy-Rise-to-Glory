-- Add WTA AI profile portraits batch 4 (#81-#100).
-- Source images were verified in Admin/WTA AI Profiles and copied into
-- Admin/WTA Avatars before mapping.
-- Exact player identity is matched by name + country + WTA AI status.

with portraits(first_name,last_name,country_code,image_path) as (
  values
  ('Ida','Larsen','DK','WTA Avatars/Ida Larsen.png'),
  ('Alessia','Romano','IT','WTA Avatars/Alessia Romano.png'),
  ('Johanna','Bauer','DE','WTA Avatars/Johanna Bauer.png'),
  ('Camila','Carvalho','BR','WTA Avatars/Camila Carvalho.png'),
  ('Julia','Wojcik','PL','WTA Avatars/Julia Wojcik.png'),
  ('Jing','Yang','CN','WTA Avatars/Jing Yang.png'),
  ('Julieta','Ibarra','AR','WTA Avatars/Julieta Ibarra.png'),
  ('Milica','Petrovic','RS','WTA Avatars/Milica Petrovic.png'),
  ('Lucia','Cabrera','ES','WTA Avatars/Lucia Cabrera.png'),
  ('Anna','Lakatos','HU','WTA Avatars/Anna Lakatos.png'),
  ('Laura','Rantanen','FI','WTA Avatars/Laura Rantanen.png'),
  ('Sofia','Pacheco','MX','WTA Avatars/Sofia Pacheco.png'),
  ('Elisa','Rinaldi','IT','WTA Avatars/Elisa Rinaldi.png'),
  ('Valentina','Molina','AR','WTA Avatars/Valentina Molina.png'),
  ('Olivia','Parker','AU','WTA Avatars/Olivia Parker.png'),
  ('Aroha','Fraser','NZ','WTA Avatars/Aroha Fraser.png'),
  ('Amira','Jaziri','TN','WTA Avatars/Amira Jaziri.png'),
  ('Maddison','Parker','AU','WTA Avatars/Maddison Parker.png'),
  ('Emily','Foster','GB','WTA Avatars/Emily Foster.png'),
  ('Maia','McKenzie','NZ','WTA Avatars/Maia McKenzie.png')
),
validated as (
  select p.id,x.image_path
  from portraits x
  join public.players p
    on p.first_name=x.first_name
   and p.last_name=x.last_name
   and p.country_code=x.country_code
   and p.world='WTA'
   and p.player_type='ai'
  where exists(
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=x.image_path
  )
)
update public.players p
set image_path=v.image_path,
    updated_at=now()
from validated v
where p.id=v.id;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.players p
  join (
    values
    ('Ida','Larsen','DK','WTA Avatars/Ida Larsen.png'),
  ('Alessia','Romano','IT','WTA Avatars/Alessia Romano.png'),
  ('Johanna','Bauer','DE','WTA Avatars/Johanna Bauer.png'),
  ('Camila','Carvalho','BR','WTA Avatars/Camila Carvalho.png'),
  ('Julia','Wojcik','PL','WTA Avatars/Julia Wojcik.png'),
  ('Jing','Yang','CN','WTA Avatars/Jing Yang.png'),
  ('Julieta','Ibarra','AR','WTA Avatars/Julieta Ibarra.png'),
  ('Milica','Petrovic','RS','WTA Avatars/Milica Petrovic.png'),
  ('Lucia','Cabrera','ES','WTA Avatars/Lucia Cabrera.png'),
  ('Anna','Lakatos','HU','WTA Avatars/Anna Lakatos.png'),
  ('Laura','Rantanen','FI','WTA Avatars/Laura Rantanen.png'),
  ('Sofia','Pacheco','MX','WTA Avatars/Sofia Pacheco.png'),
  ('Elisa','Rinaldi','IT','WTA Avatars/Elisa Rinaldi.png'),
  ('Valentina','Molina','AR','WTA Avatars/Valentina Molina.png'),
  ('Olivia','Parker','AU','WTA Avatars/Olivia Parker.png'),
  ('Aroha','Fraser','NZ','WTA Avatars/Aroha Fraser.png'),
  ('Amira','Jaziri','TN','WTA Avatars/Amira Jaziri.png'),
  ('Maddison','Parker','AU','WTA Avatars/Maddison Parker.png'),
  ('Emily','Foster','GB','WTA Avatars/Emily Foster.png'),
  ('Maia','McKenzie','NZ','WTA Avatars/Maia McKenzie.png')
  ) as x(first_name,last_name,country_code,image_path)
    on p.first_name=x.first_name
   and p.last_name=x.last_name
   and p.country_code=x.country_code
   and p.world='WTA'
   and p.player_type='ai'
   and p.image_path=x.image_path
  where exists(
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=p.image_path
  );

  if v_count<>20 then
    raise exception 'Expected 20 WTA AI portraits after batch 4 update, found %.',v_count;
  end if;
end;
$$;

select public.check_wta_ai_portrait_health_v1();
