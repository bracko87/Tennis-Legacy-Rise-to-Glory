-- Technical sponsor brand pool for Tennis Legacy.
-- All names/logos are fictional game assets. Logos are original generated SVG marks.

create or replace function public.make_technical_brand_logo_v1(
  p_name text,
  p_primary text,
  p_secondary text,
  p_variant integer
)
returns text
language plpgsql
immutable
set search_path='public'
as $$
declare
  n text:=replace(replace(replace(coalesce(p_name,'Brand'),'&','&amp;'),'<','&lt;'),'>','&gt;');
  initials text:=upper(left(regexp_replace(coalesce(p_name,'BR'),'[^A-Za-z0-9]','','g'),2));
  mark text;
  svg text;
begin
  mark:=case ((coalesce(p_variant,1)-1)%8)+1
    when 1 then format('<path d="M54 94 L118 38 L151 51 L91 111 Z" fill="%s"/><path d="M108 112 L164 61 L187 72 L136 124 Z" fill="%s"/>',p_primary,p_secondary)
    when 2 then format('<circle cx="102" cy="81" r="42" fill="none" stroke="%s" stroke-width="15"/><circle cx="130" cy="72" r="24" fill="%s" opacity=".92"/>',p_primary,p_secondary)
    when 3 then format('<path d="M100 31 L151 49 L143 102 Q128 128 100 142 Q72 128 57 102 L49 49 Z" fill="%s"/><path d="M74 75 L98 102 L132 58" fill="none" stroke="%s" stroke-width="12" stroke-linecap="round"/>',p_primary,p_secondary)
    when 4 then format('<path d="M43 56 H137 L120 75 H26 Z" fill="%s"/><path d="M65 85 H159 L142 104 H48 Z" fill="%s"/><path d="M87 114 H181 L164 133 H70 Z" fill="%s" opacity=".72"/>',p_primary,p_secondary,p_primary)
    when 5 then format('<path d="M100 30 L157 84 L100 138 L43 84 Z" fill="%s"/><path d="M100 52 L134 84 L100 116 L66 84 Z" fill="%s"/>',p_primary,p_secondary)
    when 6 then format('<circle cx="100" cy="84" r="54" fill="%s"/><text x="100" y="96" text-anchor="middle" font-family="Arial,sans-serif" font-size="38" font-weight="900" fill="%s">%s</text>',p_primary,p_secondary,initials)
    when 7 then format('<path d="M36 104 C62 42 84 130 108 68 C132 10 158 116 184 52" fill="none" stroke="%s" stroke-width="16" stroke-linecap="round"/><circle cx="158" cy="116" r="15" fill="%s"/>',p_primary,p_secondary)
    else format('<path d="M48 45 L100 75 L152 45 L174 62 L100 105 L26 62 Z" fill="%s"/><path d="M52 91 L100 119 L148 91 L165 108 L100 146 L35 108 Z" fill="%s"/>',p_primary,p_secondary)
  end;
  svg:=format('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180"><rect width="320" height="180" rx="20" fill="white"/>%s<text x="206" y="78" text-anchor="middle" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#172b3a">%s</text><text x="206" y="101" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" font-weight="700" letter-spacing="2" fill="#71808c">TENNIS PERFORMANCE</text></svg>',mark,n);
  return 'data:image/svg+xml;base64,'||encode(convert_to(svg,'UTF8'),'base64');
end;
$$;

create table if not exists public.technical_sponsor_brands (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  country_code text not null references public.countries(code) on update cascade on delete restrict,
  region text not null,
  tier text not null check (tier in ('entry','established','premium','elite')),
  prestige smallint not null check (prestige between 1 and 100),
  budget_level smallint not null check (budget_level between 1 and 5),
  target_rank_best integer not null,
  target_rank_worst integer not null,
  min_reputation smallint not null check (min_reputation between 0 and 100),
  target_player_level text not null,
  contract_strength smallint not null check (contract_strength between 1 and 100),
  discount_min_pct numeric(5,2) not null,
  discount_max_pct numeric(5,2) not null,
  free_equipment_min smallint not null default 0,
  free_equipment_max smallint not null default 0,
  free_replacements boolean not null default false,
  maintenance_discount_min_pct numeric(5,2) not null default 0,
  maintenance_discount_max_pct numeric(5,2) not null default 0,
  contract_weeks_min smallint not null,
  contract_weeks_max smallint not null,
  generosity smallint not null check (generosity between 1 and 100),
  rarity_weight numeric(7,4) not null,
  offer_probability numeric(7,4) not null,
  philosophy text not null,
  price_level text not null,
  primary_color text not null,
  secondary_color text not null,
  logo_variant smallint not null,
  logo_url text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.technical_sponsor_brand_categories (
  brand_id uuid not null references public.technical_sponsor_brands(id) on delete cascade,
  category text not null check (category in ('racket','shoes','apparel','accessory')),
  is_primary boolean not null default false,
  product_count_target smallint not null default 1 check (product_count_target between 1 and 20),
  identity_profile text not null,
  created_at timestamptz not null default now(),
  primary key (brand_id,category)
);

create index if not exists technical_sponsor_brands_tier_idx on public.technical_sponsor_brands(tier,prestige desc) where is_active;
create index if not exists technical_sponsor_brand_categories_category_idx on public.technical_sponsor_brand_categories(category,brand_id);

with seed(code,name,country_code,region,tier,prestige,philosophy,primary_color,secondary_color,logo_variant) as (
  values
  ('ADIDIS','Adidis','DE','Europe','elite',89,'balanced performance / heritage','hsl(94 68% 42%)','hsl(253 74% 54%)',2),
  ('AMELULO','Ame Lulo','US','North America','premium',72,'premium bags / court lifestyle','hsl(127 68% 42%)','hsl(330 74% 54%)',1),
  ('ANGEL','Angel','GB','Europe','premium',76,'custom precision / control','hsl(253 68% 42%)','hsl(74 74% 54%)',3),
  ('ANTTA','Antta','CN','Asia','entry',34,'balanced value / durability','hsl(126 68% 34%)','hsl(351 74% 46%)',2),
  ('ARTENGA','Artenga','FR','Europe','entry',32,'accessible all-round tennis','hsl(173 68% 38%)','hsl(354 74% 50%)',3),
  ('ASIKS','Asiks','JP','Asia','elite',87,'stability / court movement','hsl(188 68% 38%)','hsl(9 74% 50%)',4),
  ('AUSTRALIEN','Australien','AU','Oceania','established',54,'heritage / warm-weather','hsl(205 68% 42%)','hsl(37 74% 54%)',3),
  ('BABLOT','Bablot','FR','Europe','elite',94,'spin / explosive power','hsl(2 68% 38%)','hsl(205 74% 50%)',6),
  ('BATHOO','Bathoo','ZA','Africa','entry',31,'value-focused cushioned performance footwear','hsl(204 72% 38%)','hsl(12 74% 54%)',2),
  ('BJORNBORGA','Bjern Borga','SE','Europe','premium',73,'Scandinavian performance','hsl(95 68% 38%)','hsl(287 74% 50%)',1),
  ('BLOKUV','BlokUV','US','North America','entry',29,'sun protection','hsl(17 68% 38%)','hsl(165 74% 50%)',7),
  ('BOSSO','Bosso','DE','Europe','elite',91,'luxury minimalism','hsl(142 68% 42%)','hsl(345 74% 54%)',2),
  ('CANCHA','Cancha','GB','Europe','established',51,'modular tennis bags','hsl(80 68% 38%)','hsl(272 74% 50%)',8),
  ('CASTORA','Castora','GB','Europe','premium',75,'technical fabric / modern fit','hsl(48 68% 34%)','hsl(229 74% 46%)',8),
  ('COURTCUTURE','Court Cuture','US','North America','premium',76,'luxury court style','hsl(299 68% 38%)','hsl(153 74% 50%)',5),
  ('DIADEMA','Diadema','US','North America','premium',70,'spin / modern control','hsl(112 68% 42%)','hsl(315 74% 54%)',8),
  ('DIADORO','Diadoro','IT','Europe','established',52,'craft / all-court','hsl(329 68% 38%)','hsl(183 74% 50%)',7),
  ('DONNEI','Donnei','GB','Europe','premium',72,'classic feel / precision','hsl(65 68% 38%)','hsl(257 74% 50%)',7),
  ('DUNLUP','Dunlup','GB','Europe','premium',72,'control / traditional feel','hsl(143 68% 38%)','hsl(324 74% 50%)',1),
  ('ELLESY','Ellesy','GB','Europe','established',52,'heritage court fashion','hsl(1 68% 42%)','hsl(171 74% 54%)',7),
  ('FEETURS','Feeturs','US','North America','entry',31,'performance socks / blister control','hsl(33 68% 34%)','hsl(214 74% 46%)',7),
  ('FILIA','Filia','IT','Europe','established',54,'classic tennis / comfort','hsl(282 68% 34%)','hsl(125 74% 46%)',6),
  ('FISCHAR','Fischar','AT','Europe','established',51,'flex / precision','hsl(347 68% 38%)','hsl(190 74% 50%)',5),
  ('GAMA','Gama','US','North America','entry',35,'accessible performance','hsl(159 68% 34%)','hsl(318 74% 46%)',1),
  ('GEOSPORT','Geo Sport','US','North America','premium',70,'durable travel bags','hsl(174 68% 34%)','hsl(333 74% 46%)',2),
  ('HED','Hed','AT','Europe','elite',87,'control / modern power','hsl(315 68% 34%)','hsl(147 74% 46%)',5),
  ('HOKKA','Hokka','FR','Europe','premium',74,'maximum cushioning','hsl(32 68% 38%)','hsl(235 74% 50%)',8),
  ('HYDROGIN','Hydrogin','IT','Europe','premium',70,'bold technical fashion','hsl(189 68% 34%)','hsl(348 74% 46%)',3),
  ('IBKOOL','IBKool','US','North America','entry',31,'cooling / hot weather','hsl(330 68% 34%)','hsl(162 74% 46%)',6),
  ('JOMAE','Jomae','ES','Europe','entry',29,'value / durability','hsl(251 68% 38%)','hsl(116 74% 50%)',5),
  ('KNEISL','Kneisl','AT','Europe','premium',73,'premium traditional control','hsl(34 68% 42%)','hsl(193 74% 54%)',6),
  ('KSWIS','K-Swis','US','North America','premium',72,'durability / court stability','hsl(16 68% 42%)','hsl(241 74% 54%)',8),
  ('LACOSTA','Lacosta','FR','Europe','elite',91,'premium classic / precision','hsl(220 68% 42%)','hsl(52 74% 54%)',4),
  ('LECOQ','Le Coq Sportiv','FR','Europe','premium',73,'heritage / style','hsl(267 68% 34%)','hsl(110 74% 46%)',5),
  ('LININ','Li-Nin','CN','Asia','premium',72,'explosive speed / innovation','hsl(79 68% 42%)','hsl(293 74% 54%)',1),
  ('LOTTA','Lotta','IT','Europe','entry',31,'value / classic court','hsl(204 68% 34%)','hsl(58 74% 46%)',4),
  ('LUCKI','Lucki In Love','US','North America','premium',74,'fashion-forward performance','hsl(111 68% 34%)','hsl(281 74% 46%)',1),
  ('MIZUNA','Mizuna','JP','Asia','premium',70,'precision / movement','hsl(63 68% 34%)','hsl(244 74% 46%)',1),
  ('NEWBALANS','New Balans','US','North America','premium',71,'comfort / fit / stability','hsl(235 68% 42%)','hsl(67 74% 54%)',5),
  ('NOIK','Noik','US','North America','elite',91,'global performance / speed','hsl(47 68% 38%)','hsl(195 74% 50%)',1),
  ('OLYMPIKOS','Olympikos','BR','South America','established',55,'durable South American court footwear','hsl(166 70% 35%)','hsl(42 82% 52%)',3),
  ('ONN','Onn','CH','Europe','premium',77,'lightweight / modern speed','hsl(110 68% 38%)','hsl(302 74% 50%)',2),
  ('PACIFIK','Pacifik','DE','Europe','established',54,'comfort / touch','hsl(206 68% 38%)','hsl(16 74% 50%)',2),
  ('PENALTI','Penalti','BR','South America','entry',34,'accessible warm-weather match clothing','hsl(26 78% 45%)','hsl(216 70% 45%)',5),
  ('PENGWIN','Original Pengwin','US','North America','established',50,'heritage casual court','hsl(236 68% 38%)','hsl(46 74% 50%)',4),
  ('PRINC','Princ','US','North America','premium',74,'comfort / classic all-round','hsl(96 68% 34%)','hsl(321 74% 46%)',8),
  ('PROKENEX','ProKenex','TW','Asia','premium',75,'comfort / vibration control','hsl(284 68% 38%)','hsl(138 74% 50%)',4),
  ('PUMMA','Pumma','DE','Europe','premium',71,'speed / lightweight','hsl(141 68% 34%)','hsl(311 74% 46%)',3),
  ('QIAODEN','Qiaoden','CN','Asia','entry',30,'budget athletic performance','hsl(128 68% 38%)','hsl(309 74% 50%)',8),
  ('RAINYA','Rainya','BR','South America','established',49,'classic Brazilian court apparel','hsl(306 64% 42%)','hsl(76 72% 44%)',7),
  ('REEBAK','Reebak','GB','Europe','established',52,'retro performance / comfort','hsl(298 68% 42%)','hsl(174 74% 54%)',6),
  ('ROHNISH','Rohnish','GB','Europe','established',52,'lightweight performance','hsl(252 68% 34%)','hsl(95 74% 46%)',4),
  ('ROSIGNOL','Rosignol','FR','Europe','entry',32,'heritage / feel','hsl(81 68% 34%)','hsl(251 74% 46%)',7),
  ('SKECHORS','Skechors','US','North America','established',50,'comfort / cushioning','hsl(345 68% 34%)','hsl(177 74% 46%)',7),
  ('SLAZENGAR','Slazengar','GB','Europe','established',51,'heritage / balanced value','hsl(18 68% 34%)','hsl(199 74% 46%)',6),
  ('SOFIBELA','Sofibela','US','North America','entry',36,'comfort / modern court','hsl(64 68% 42%)','hsl(223 74% 54%)',8),
  ('SOLINKA','Solinka','US','North America','premium',73,'spin / aggressive baseline','hsl(331 68% 42%)','hsl(196 74% 54%)',5),
  ('SPALDIN','Spaldin','US','North America','entry',30,'heritage / durable value','hsl(300 68% 34%)','hsl(132 74% 46%)',4),
  ('TACHINI','Sergio Tachini','IT','Europe','premium',71,'retro premium matchwear','hsl(314 68% 38%)','hsl(168 74% 50%)',6),
  ('TASC','Task','US','North America','entry',33,'breathable natural fabrics','hsl(283 68% 42%)','hsl(104 74% 54%)',5),
  ('TECNIFIBRA','Tecnifibra','FR','Europe','premium',70,'precision / fast swing','hsl(190 68% 42%)','hsl(22 74% 54%)',2),
  ('THORLA','Thorla','US','North America','established',53,'foot comfort / socks','hsl(346 68% 42%)','hsl(156 74% 54%)',6),
  ('TIFOSY','Tifosy','GB','Europe','established',54,'sport eyewear / sun protection','hsl(221 68% 38%)','hsl(31 74% 50%)',3),
  ('TRAVISMATIO','Travis Matio','US','North America','premium',72,'premium lifestyle tennis','hsl(158 68% 38%)','hsl(339 74% 50%)',2),
  ('UNDERARMER','Under Armer','US','North America','established',53,'athletic fit / power','hsl(157 68% 42%)','hsl(0 74% 54%)',3),
  ('VOLKEL','Volkel','DE','Europe','premium',77,'comfort / arm-friendly control','hsl(237 68% 34%)','hsl(80 74% 46%)',3),
  ('WILSAN','Wilsan','US','North America','elite',89,'balanced tour / precision','hsl(268 68% 42%)','hsl(89 74% 54%)',4),
  ('YONNEX','Yonnex','JP','Asia','elite',92,'precision / sweet spot','hsl(49 68% 42%)','hsl(263 74% 54%)',7)
)
insert into public.technical_sponsor_brands(
  code,name,country_code,region,tier,prestige,budget_level,target_rank_best,target_rank_worst,min_reputation,
  target_player_level,contract_strength,discount_min_pct,discount_max_pct,free_equipment_min,free_equipment_max,
  free_replacements,maintenance_discount_min_pct,maintenance_discount_max_pct,contract_weeks_min,contract_weeks_max,
  generosity,rarity_weight,offer_probability,philosophy,price_level,primary_color,secondary_color,logo_variant,logo_url,metadata
)
select
  code,name,country_code,region,tier,prestige,
  case tier when 'entry' then 1 when 'established' then 2 when 'premium' then 4 else 5 end,
  case tier when 'entry' then 500 when 'established' then 120 when 'premium' then 20 else 1 end,
  case tier when 'entry' then 5000 when 'established' then 2500 when 'premium' then 900 else 250 end,
  case tier when 'entry' then 8 when 'established' then 22 when 'premium' then 42 else 65 end,
  case tier when 'entry' then 'Juniors / lower-ranked professionals' when 'established' then 'Developing professionals / tour regulars' when 'premium' then 'Established professionals / ranked players' else 'Top-ranked / high-reputation players' end,
  least(95,greatest(25,prestige-5)),
  case tier when 'entry' then 5 when 'established' then 10 when 'premium' then 20 else 35 end,
  case tier when 'entry' then 14 when 'established' then 24 when 'premium' then 40 else 60 end,
  case tier when 'entry' then 0 when 'established' then 1 when 'premium' then 2 else 5 end,
  case tier when 'entry' then 1 when 'established' then 3 when 'premium' then 6 else 10 end,
  tier in ('premium','elite'),
  case tier when 'entry' then 0 when 'established' then 8 when 'premium' then 18 else 30 end,
  case tier when 'entry' then 10 when 'established' then 20 when 'premium' then 35 else 50 end,
  case tier when 'entry' then 12 when 'established' then 20 when 'premium' then 26 else 40 end,
  case tier when 'entry' then 24 when 'established' then 40 when 'premium' then 52 else 78 end,
  least(82,greatest(52,prestige-20)),
  case tier when 'entry' then 1.35 when 'established' then 1.00 when 'premium' then .72 else .42 end,
  case tier when 'entry' then .105 when 'established' then .082 when 'premium' then .058 else .035 end,
  philosophy,
  case tier when 'entry' then 'value' when 'established' then 'mid-range' when 'premium' then 'premium' else 'elite' end,
  primary_color,secondary_color,logo_variant,
  public.make_technical_brand_logo_v1(name,primary_color,secondary_color,logo_variant),
  jsonb_build_object('fictional',true,'pool_version',1)
from seed
on conflict(code) do update set
  name=excluded.name,country_code=excluded.country_code,region=excluded.region,tier=excluded.tier,prestige=excluded.prestige,
  philosophy=excluded.philosophy,primary_color=excluded.primary_color,secondary_color=excluded.secondary_color,
  logo_variant=excluded.logo_variant,logo_url=excluded.logo_url,is_active=true,updated_at=now();

with category_seed(code,category,target,is_primary,identity_profile) as (
  values
  ('ADIDIS','apparel',4,true,'balanced performance / heritage; unified clothing collections for match and warm-up use'),('ADIDIS','shoes',4,false,'balanced performance / heritage; footwear line with all-court and surface-specific models'),
  ('AMELULO','accessory',3,true,'premium bags / court lifestyle; practical court accessories with small support bonuses'),('ANGEL','racket',5,true,'custom precision / control; racquet line focused on tour balance'),
  ('ANTTA','shoes',4,true,'balanced value / durability; footwear line with all-court and surface-specific models'),('ARTENGA','apparel',4,true,'accessible all-round tennis; unified clothing collections for match and warm-up use'),
  ('ASIKS','shoes',4,true,'stability / court movement; footwear line with all-court and surface-specific models'),('AUSTRALIEN','apparel',4,true,'heritage / warm-weather; unified clothing collections for match and warm-up use'),
  ('BABLOT','racket',5,true,'spin / explosive power; racquet line focused on tour balance'),('BABLOT','accessory',3,false,'spin / explosive power; practical court accessories with small support bonuses'),
  ('BATHOO','shoes',4,true,'value-focused cushioned performance footwear; all-court and surface-specialist models'),('BJORNBORGA','apparel',4,true,'Scandinavian performance; unified clothing collections for match and warm-up use'),
  ('BLOKUV','apparel',4,true,'sun protection; unified clothing collections for match and warm-up use'),('BOSSO','apparel',4,true,'luxury minimalism; unified clothing collections for match and warm-up use'),
  ('CANCHA','accessory',3,true,'modular tennis bags; practical court accessories with small support bonuses'),('CASTORA','apparel',4,true,'technical fabric / modern fit; unified clothing collections for match and warm-up use'),
  ('COURTCUTURE','apparel',4,true,'luxury court style; unified clothing collections for match and warm-up use'),('DIADEMA','racket',5,true,'spin / modern control; racquet line focused on tour balance'),
  ('DIADORO','shoes',4,true,'craft / all-court; footwear line with all-court and surface-specific models'),('DONNEI','racket',5,true,'classic feel / precision; racquet line focused on tour balance'),
  ('DUNLUP','racket',5,true,'control / traditional feel; racquet line focused on tour balance'),('DUNLUP','accessory',3,false,'control / traditional feel; practical court accessories with small support bonuses'),
  ('ELLESY','apparel',4,true,'heritage court fashion; unified clothing collections for match and warm-up use'),('FEETURS','accessory',3,true,'performance socks / blister control; practical court accessories with small support bonuses'),
  ('FILIA','shoes',4,true,'classic tennis / comfort; footwear line with all-court and surface-specific models'),('FISCHAR','racket',5,true,'flex / precision; racquet line focused on accessible performance'),
  ('GAMA','racket',5,true,'accessible performance; racquet line focused on accessible performance'),('GEOSPORT','accessory',3,true,'durable travel bags; practical court accessories with small support bonuses'),
  ('HED','racket',5,true,'control / modern power; racquet line focused on tour balance'),('HED','accessory',3,false,'control / modern power; practical court accessories with small support bonuses'),
  ('HOKKA','shoes',4,true,'maximum cushioning; footwear line with all-court and surface-specific models'),('HYDROGIN','apparel',4,true,'bold technical fashion; unified clothing collections for match and warm-up use'),
  ('IBKOOL','apparel',4,true,'cooling / hot weather; unified clothing collections for match and warm-up use'),('JOMAE','shoes',4,true,'value / durability; footwear line with all-court and surface-specific models'),
  ('KNEISL','racket',5,true,'premium traditional control; racquet line focused on tour balance'),('KSWIS','shoes',4,true,'durability / court stability; footwear line with all-court and surface-specific models'),
  ('LACOSTA','apparel',4,true,'premium classic / precision; unified clothing collections for match and warm-up use'),('LECOQ','apparel',4,true,'heritage / style; unified clothing collections for match and warm-up use'),
  ('LININ','shoes',4,true,'explosive speed / innovation; footwear line with all-court and surface-specific models'),('LOTTA','shoes',4,true,'value / classic court; footwear line with all-court and surface-specific models'),
  ('LUCKI','apparel',4,true,'fashion-forward performance; unified clothing collections for match and warm-up use'),('MIZUNA','shoes',4,true,'precision / movement; footwear line with all-court and surface-specific models'),
  ('NEWBALANS','shoes',4,true,'comfort / fit / stability; footwear line with all-court and surface-specific models'),('NOIK','apparel',4,true,'global performance / speed; unified clothing collections for match and warm-up use'),
  ('NOIK','shoes',4,false,'global performance / speed; footwear line with all-court and surface-specific models'),('OLYMPIKOS','shoes',4,true,'durable South American court footwear; all-court and surface-specialist models'),
  ('ONN','shoes',4,true,'lightweight / modern speed; footwear line with all-court and surface-specific models'),('PACIFIK','racket',5,true,'comfort / touch; racquet line focused on accessible performance'),
  ('PENALTI','apparel',4,true,'accessible warm-weather match clothing; unified clothing collections'),('PENGWIN','apparel',4,true,'heritage casual court; unified clothing collections for match and warm-up use'),
  ('PRINC','racket',5,true,'comfort / classic all-round; racquet line focused on tour balance'),('PRINC','accessory',3,false,'comfort / classic all-round; practical court accessories with small support bonuses'),
  ('PROKENEX','racket',5,true,'comfort / vibration control; racquet line focused on tour balance'),('PUMMA','shoes',4,true,'speed / lightweight; footwear line with all-court and surface-specific models'),
  ('QIAODEN','apparel',4,true,'budget athletic performance; unified clothing collections for match and warm-up use'),('RAINYA','apparel',4,true,'classic Brazilian court apparel; unified clothing collections'),
  ('REEBAK','shoes',4,true,'retro performance / comfort; footwear line with all-court and surface-specific models'),('ROHNISH','apparel',4,true,'lightweight performance; unified clothing collections for match and warm-up use'),
  ('ROSIGNOL','racket',5,true,'heritage / feel; racquet line focused on accessible performance'),('SKECHORS','shoes',4,true,'comfort / cushioning; footwear line with all-court and surface-specific models'),
  ('SLAZENGAR','racket',5,true,'heritage / balanced value; racquet line focused on accessible performance'),('SOFIBELA','apparel',4,true,'comfort / modern court; unified clothing collections for match and warm-up use'),
  ('SOLINKA','racket',5,true,'spin / aggressive baseline; racquet line focused on tour balance'),('SOLINKA','accessory',3,false,'spin / aggressive baseline; practical court accessories with small support bonuses'),
  ('SPALDIN','racket',5,true,'heritage / durable value; racquet line focused on accessible performance'),('TACHINI','apparel',4,true,'retro premium matchwear; unified clothing collections for match and warm-up use'),
  ('TASC','apparel',4,true,'breathable natural fabrics; unified clothing collections for match and warm-up use'),('TECNIFIBRA','racket',5,true,'precision / fast swing; racquet line focused on tour balance'),
  ('TECNIFIBRA','accessory',3,false,'precision / fast swing; practical court accessories with small support bonuses'),('THORLA','accessory',3,true,'foot comfort / socks; practical court accessories with small support bonuses'),
  ('TIFOSY','accessory',3,true,'sport eyewear / sun protection; practical court accessories with small support bonuses'),('TRAVISMATIO','apparel',4,true,'premium lifestyle tennis; unified clothing collections for match and warm-up use'),
  ('UNDERARMER','shoes',4,true,'athletic fit / power; footwear line with all-court and surface-specific models'),('VOLKEL','racket',5,true,'comfort / arm-friendly control; racquet line focused on tour balance'),
  ('WILSAN','racket',5,true,'balanced tour / precision; racquet line focused on tour balance'),('WILSAN','accessory',3,false,'balanced tour / precision; practical court accessories with small support bonuses'),
  ('YONNEX','racket',5,true,'precision / sweet spot; racquet line focused on tour balance'),('YONNEX','accessory',3,false,'precision / sweet spot; practical court accessories with small support bonuses')
)
insert into public.technical_sponsor_brand_categories(brand_id,category,is_primary,product_count_target,identity_profile)
select b.id,s.category,s.is_primary,s.target,s.identity_profile
from category_seed s join public.technical_sponsor_brands b on b.code=s.code
on conflict(brand_id,category) do update set is_primary=excluded.is_primary,product_count_target=excluded.product_count_target,identity_profile=excluded.identity_profile;
