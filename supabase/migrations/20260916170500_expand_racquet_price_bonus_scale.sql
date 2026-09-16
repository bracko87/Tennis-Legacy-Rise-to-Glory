-- Expand the racquet economy from entry equipment to premium pro equipment.
-- Also make the marketplace profile line explain the strongest intended match use.
-- Match effects remain automatic because the match engine reads gameplay_effects from the selected setup.

with base as (
  select
    e.id,
    e.tier,
    split_part(lower(coalesce(e.product_profile,'balanced')),' · ',1) as profile,
    coalesce(b.prestige,50) as prestige
  from public.equipment_catalog_items e
  join public.technical_sponsor_brands b on b.id=e.technical_brand_id
  where e.item_type='racket'
    and e.is_active
    and e.availability_status='available'
), tuned as (
  select
    id,
    tier,
    profile,
    greatest(105, round((case tier
      when 5 then 2300 + case profile when 'balanced' then 0 when 'power' then 250 when 'control' then 350 when 'spin' then 450 when 'precision' then 550 else 150 end + greatest(0,prestige-80)*10
      when 4 then 1050 + case profile when 'balanced' then 0 when 'power' then 220 when 'control' then 320 when 'spin' then 480 when 'precision' then 650 else 120 end + greatest(0,prestige-65)*8
      when 3 then 500 + case profile when 'balanced' then 0 when 'power' then 100 when 'control' then 150 when 'spin' then 220 when 'precision' then 300 else 80 end + greatest(0,prestige-50)*4
      when 2 then 220 + case profile when 'balanced' then 0 when 'power' then 50 when 'control' then 75 when 'spin' then 110 when 'precision' then 145 else 40 end + greatest(0,prestige-45)*3
      else 101 + case profile when 'balanced' then 0 when 'power' then 25 when 'control' then 40 when 'spin' then 55 when 'precision' then 70 else 15 end + greatest(0,prestige-30)*2
    end)/5.0)*5)::bigint as new_price,
    case tier when 5 then 0.80 when 4 then 1.00 when 3 then 1.25 when 2 then 1.55 else 1.90 end::numeric as new_wear,
    case profile
      when 'balanced' then case tier
        when 5 then jsonb_build_object('power_pct',1.40,'control_pct',1.40,'spin_pct',1.20,'rally_pct',1.15,'serve_pct',0.80,'return_pct',0.80,'forehand_pct',0.55,'backhand_pct',0.55,'net_pct',0.50)
        when 4 then jsonb_build_object('power_pct',0.95,'control_pct',0.95,'spin_pct',0.85,'rally_pct',0.82,'serve_pct',0.58,'return_pct',0.58,'forehand_pct',0.40,'backhand_pct',0.40,'net_pct',0.36)
        when 3 then jsonb_build_object('power_pct',0.55,'control_pct',0.55,'spin_pct',0.50,'rally_pct',0.50,'serve_pct',0.34,'return_pct',0.34,'forehand_pct',0.24,'backhand_pct',0.24,'net_pct',0.22)
        when 2 then jsonb_build_object('power_pct',0.30,'control_pct',0.30,'spin_pct',0.26,'rally_pct',0.28,'serve_pct',0.18,'return_pct',0.18,'forehand_pct',0.13,'backhand_pct',0.13,'net_pct',0.12)
        else jsonb_build_object('power_pct',0.15,'control_pct',0.15,'spin_pct',0.13,'rally_pct',0.14,'serve_pct',0.08,'return_pct',0.08,'forehand_pct',0.06,'backhand_pct',0.06,'net_pct',0.05) end
      when 'power' then case tier
        when 5 then jsonb_build_object('power_pct',2.85,'serve_pct',2.45,'forehand_pct',1.45,'rally_pct',1.10,'return_pct',-0.08,'control_pct',-0.12)
        when 4 then jsonb_build_object('power_pct',2.05,'serve_pct',1.75,'forehand_pct',1.05,'rally_pct',0.80,'return_pct',-0.08,'control_pct',-0.12)
        when 3 then jsonb_build_object('power_pct',1.35,'serve_pct',1.15,'forehand_pct',0.72,'rally_pct',0.52,'return_pct',-0.06,'control_pct',-0.10)
        when 2 then jsonb_build_object('power_pct',0.75,'serve_pct',0.64,'forehand_pct',0.40,'rally_pct',0.28,'return_pct',-0.04,'control_pct',-0.08)
        else jsonb_build_object('power_pct',0.45,'serve_pct',0.38,'forehand_pct',0.25,'rally_pct',0.16,'return_pct',-0.03,'control_pct',-0.06) end
      when 'control' then case tier
        when 5 then jsonb_build_object('control_pct',2.80,'return_pct',2.30,'backhand_pct',1.40,'rally_pct',1.10,'net_pct',1.00,'power_pct',-0.10)
        when 4 then jsonb_build_object('control_pct',2.00,'return_pct',1.65,'backhand_pct',1.00,'rally_pct',0.80,'net_pct',0.70,'power_pct',-0.10)
        when 3 then jsonb_build_object('control_pct',1.30,'return_pct',1.05,'backhand_pct',0.68,'rally_pct',0.52,'net_pct',0.45,'power_pct',-0.08)
        when 2 then jsonb_build_object('control_pct',0.75,'return_pct',0.59,'backhand_pct',0.37,'rally_pct',0.28,'net_pct',0.24,'power_pct',-0.06)
        else jsonb_build_object('control_pct',0.45,'return_pct',0.36,'backhand_pct',0.24,'rally_pct',0.16,'net_pct',0.12,'power_pct',-0.04) end
      when 'spin' then case tier
        when 5 then jsonb_build_object('spin_pct',3.10,'rally_pct',2.15,'forehand_pct',1.45,'serve_pct',1.00,'return_pct',0.80,'comfort_pct',-0.08)
        when 4 then jsonb_build_object('spin_pct',2.30,'rally_pct',1.60,'forehand_pct',1.05,'serve_pct',0.70,'return_pct',0.55,'comfort_pct',-0.08)
        when 3 then jsonb_build_object('spin_pct',1.55,'rally_pct',1.08,'forehand_pct',0.72,'serve_pct',0.45,'return_pct',0.36,'comfort_pct',-0.06)
        when 2 then jsonb_build_object('spin_pct',0.90,'rally_pct',0.58,'forehand_pct',0.40,'serve_pct',0.26,'return_pct',0.20,'comfort_pct',-0.05)
        else jsonb_build_object('spin_pct',0.50,'rally_pct',0.34,'forehand_pct',0.24,'serve_pct',0.14,'return_pct',0.10,'comfort_pct',-0.04) end
      when 'precision' then case tier
        when 5 then jsonb_build_object('control_pct',2.95,'return_pct',2.20,'net_pct',1.90,'backhand_pct',1.35,'rally_pct',1.00,'serve_pct',0.80)
        when 4 then jsonb_build_object('control_pct',2.15,'return_pct',1.55,'net_pct',1.35,'backhand_pct',0.95,'rally_pct',0.74,'serve_pct',0.55)
        when 3 then jsonb_build_object('control_pct',1.40,'return_pct',1.00,'net_pct',0.92,'backhand_pct',0.65,'rally_pct',0.48,'serve_pct',0.35)
        when 2 then jsonb_build_object('control_pct',0.80,'return_pct',0.56,'net_pct',0.50,'backhand_pct',0.35,'rally_pct',0.25,'serve_pct',0.18)
        else jsonb_build_object('control_pct',0.48,'return_pct',0.34,'net_pct',0.30,'backhand_pct',0.20,'rally_pct',0.16,'serve_pct',0.10) end
      else jsonb_build_object('power_pct',0.20,'control_pct',0.20,'spin_pct',0.18,'rally_pct',0.18)
    end as new_effects,
    case profile
      when 'power' then 'power · best for serve + forehand'
      when 'control' then 'control · best for return + backhand'
      when 'spin' then 'spin · best for spin + rally'
      when 'precision' then 'precision · best for control + net play'
      else 'balanced · best for power + control'
    end as display_profile
  from base
)
update public.equipment_catalog_items e
set
  price_usd=t.new_price,
  gameplay_effects=t.new_effects,
  wear_per_match=t.new_wear,
  estimated_uses=greatest(1,round(100.0/t.new_wear))::smallint,
  product_profile=t.display_profile
from tuned t
where e.id=t.id;
