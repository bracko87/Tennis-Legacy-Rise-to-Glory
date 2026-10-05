
-- Replace the 40 active Private Life car catalog entries with fictionalized,
-- real-world-inspired cars and realistic USD price anchors.
-- Existing catalog codes are preserved so owned assets remain valid.

with car_updates(
  code,name,purchase_price,tier,prestige,rarity,
  annual_value_rate_bps,resale_discount_bps,
  brand_name,model_name,real_life_inspiration,country_origin,vehicle_segment,description
) as (
  values
  ('car_bayside_micro','Fiato Cinquecento City',6500,1,1,'common',-900,1500,'Fiato','Cinquecento City','Fiat 500','Italy','city_car','A compact used city car with low running costs for a player at the start of a professional career.'),
  ('car_novara_economy','Renaut Clioe',9000,1,1,'common',-900,1450,'Renaut','Clioe','Renault Clio','France','economy_hatch','An affordable used hatchback with practical everyday space and modest prestige.'),
  ('car_elmford_compact','Toyoda Corola',12500,1,1,'common',-850,1400,'Toyoda','Corola','Toyota Corolla','Japan','compact','A dependable compact car known for simple ownership and strong everyday practicality.'),
  ('car_mareno_family_hatch','Volkswagon Golfe',16000,1,1,'common',-850,1350,'Volkswagon','Golfe','Volkswagen Golf','Germany','family_hatch','A versatile hatchback balancing comfort, practicality and a little more status.'),
  ('car_vale_touring_wagon','Skovia Octava Touring',19500,1,1,'common',-850,1300,'Skovia','Octava Touring','Skoda Octavia Combi','Czech Republic','wagon','A practical touring wagon with useful luggage space for long tournament trips.'),
  ('car_astor_sedan','Hyundra i20',23000,1,1,'common',-1350,1250,'Hyundra','i20','Hyundai i20','South Korea','hatchback','A modern compact hatchback with contemporary equipment and low ownership complexity.'),
  ('car_city_compact','Hondo Accorda',29000,1,2,'common',-1300,1200,'Hondo','Accorda','Honda Accord','Japan','sedan','A comfortable and reliable mid-size sedan for regular travel between events.'),
  ('car_corda_crossover','Nissin Qashkai',30500,1,2,'common',-1350,1200,'Nissin','Qashkai','Nissan Qashqai','Japan','compact_crossover','A compact crossover with practical space and modern everyday comfort.'),
  ('car_solara_hybrid','Toyoda Prios Hybrid',31000,1,2,'common',-1250,1150,'Toyoda','Prios Hybrid','Toyota Prius','Japan','hybrid','An efficient hybrid for players who want modern transport with lower fuel use.'),
  ('car_harbor_hatch','Peugeon 308',32000,1,2,'common',-1350,1150,'Peugeon','308','Peugeot 308','France','hatchback','A stylish European hatchback with a more premium cabin and balanced road manners.'),
  ('car_executive_compact','Maza 6 Executive',35000,1,2,'common',-1250,1100,'Maza','6 Executive','Mazda 6','Japan','executive_sedan','A refined executive sedan with understated styling and a strong touring focus.'),
  ('car_evermont_sport_compact','Maza MX-5 Roadster',36650,1,3,'uncommon',-1100,1050,'Maza','MX-5 Roadster','Mazda MX-5 Miata','Japan','roadster','A lightweight two-seat roadster offering genuine sports-car character at an attainable price.'),
  ('car_novaro_sedan','Auda A3 Executive',40100,2,3,'uncommon',-1400,1050,'Auda','A3 Executive','Audi A3','Germany','premium_compact','A premium compact sedan with modern technology and an executive image.'),
  ('car_lucent_roadster','Forde Focus ST',44000,2,3,'uncommon',-1250,1000,'Forde','Focus ST','Ford Focus ST','United States','sport_compact','A quick performance hatchback combining everyday usefulness with stronger sporting appeal.'),
  ('car_velaris_touring','Lexis NX 350',46220,2,3,'uncommon',-1300,1000,'Lexis','NX 350','Lexus NX 350','Japan','premium_crossover','A premium crossover with comfort, refinement and a polished luxury image.'),
  ('car_arden_crossover','BMV M240i Coupe',53600,2,4,'uncommon',-1200,950,'BMV','M240i Coupe','BMW M240i','Germany','performance_coupe','A compact performance coupe with strong acceleration and premium everyday usability.'),
  ('car_performance_coupe','BMV 330 Touring',58000,2,4,'uncommon',-1250,950,'BMV','330 Touring','BMW 3 Series Touring','Germany','premium_wagon','A premium sport wagon combining long-distance practicality with executive prestige.'),
  ('car_orison_electric','Lucida Air Touring',82000,2,4,'uncommon',-1800,950,'Lucida','Air Touring','Lucid Air Touring','United States','electric_luxury_sedan','A long-range luxury electric sedan with modern technology and strong lifestyle prestige.'),
  ('car_montaire_sport_sedan','Mercedez-AG C63',90000,2,5,'uncommon',-1300,900,'Mercedez-AG','C63','Mercedes-AMG C63','Germany','performance_sedan','A high-performance premium sedan for successful players who still want everyday usability.'),
  ('car_luxury_sedan','Chevrolay Corvett Z06',120300,3,6,'rare',-1000,850,'Chevrolay','Corvett Z06','Chevrolet Corvette Z06','United States','sports_car','A focused mid-engine sports car delivering supercar-level performance at a lower purchase price.'),
  ('car_avelon_grand_tourer','Mercedez S580',130000,3,6,'rare',-1200,850,'Mercedez','S580','Mercedes-Benz S580','Germany','luxury_sedan','A flagship luxury sedan focused on comfort, technology and understated prestige.'),
  ('car_vantor_performance_suv','Range Rovar Sport SV',153850,3,7,'rare',-1150,800,'Range Rovar','Sport SV','Range Rover Sport SV','United Kingdom','performance_suv','A high-performance luxury SUV with strong road presence and premium practicality.'),
  ('car_sports_roadster','Porscha 911 Carrera S',156200,3,8,'rare',-850,750,'Porscha','911 Carrera S','Porsche 911 Carrera S','Germany','sports_car','An iconic rear-engine sports car balancing prestige, performance and daily usability.'),
  ('car_solenne_coupe','Nissin GT-R Nisma',221000,3,8,'rare',-650,750,'Nissin','GT-R Nisma','Nissan GT-R Nismo','Japan','performance_coupe','A limited high-performance coupe with strong collector appeal and a famous motorsport-inspired character.'),
  ('car_caelus_roadster','Ferrani Roma Spider',277000,3,9,'rare',-850,700,'Ferrani','Roma Spider','Ferrari Roma Spider','Italy','grand_touring_roadster','An elegant open-top grand tourer blending luxury, performance and high prestige.'),
  ('car_ferrovia_super_sedan','Bentlay Flying Spur Speed',300000,3,10,'rare',-900,700,'Bentlay','Flying Spur Speed','Bentley Flying Spur Speed','United Kingdom','ultra_luxury_sedan','An ultra-luxury performance sedan with handcrafted comfort and substantial status.'),
  ('car_supercar','McLarin 750S Spider',350000,3,11,'rare',-750,650,'McLarin','750S Spider','McLaren 750S Spider','United Kingdom','supercar','A lightweight open-top supercar with extreme performance and strong exotic-car prestige.'),
  ('car_valcrest_v12','Ferrani DodiciCilindri',465994,4,12,'very_rare',-650,650,'Ferrani','DodiciCilindri','Ferrari 12Cilindri','Italy','v12_grand_tourer','A modern V12 grand tourer combining flagship performance with long-distance luxury.'),
  ('car_flagship_gt','Rolls Roye Specter Black Badge',467750,4,13,'very_rare',-900,600,'Rolls Roye','Specter Black Badge','Rolls-Royce Spectre Black Badge','United Kingdom','ultra_luxury_gt','An electric ultra-luxury coupe with bespoke craftsmanship and exceptional status.'),
  ('car_asterion_track','Lamborgini Revuelto',608358,4,14,'very_rare',-650,600,'Lamborgini','Revuelto','Lamborghini Revuelto','Italy','supercar','A flagship V12 hybrid supercar with dramatic styling and elite prestige.'),
  ('car_classic_collector','Porscha 911 Carrera RS 2.7',650000,4,15,'very_rare',300,550,'Porscha','911 Carrera RS 2.7','Porsche 911 Carrera RS 2.7','Germany','classic_collectible','A highly collectible lightweight classic whose value can appreciate rather than follow normal depreciation.'),
  ('car_bellwyn_classic','Ferrani SF90 XX Spider',995000,4,17,'very_rare',0,550,'Ferrani','SF90 XX Spider','Ferrari SF90 XX Spider','Italy','limited_supercar','A highly limited open-top performance special positioned above conventional production supercars.'),
  ('car_nocturne_gt','Mercedez 300 SL Gullwinge',1550000,4,19,'very_rare',250,500,'Mercedez','300 SL Gullwinge','Mercedes-Benz 300 SL Gullwing','Germany','classic_collectible','One of the most recognizable post-war collector cars, valued for rarity, design and historical importance.'),
  ('car_grand_verne_speedster','Porscha 918 Spyder',2200000,5,21,'legendary',150,500,'Porscha','918 Spyder','Porsche 918 Spyder','Germany','hybrid_hypercar','A limited hybrid hypercar with major collector demand and modern automotive significance.'),
  ('car_hypercar','Rimacca Nevera R',2500000,5,23,'legendary',-250,450,'Rimacca','Nevera R','Rimac Nevera R','Croatia','electric_hypercar','An ultra-low-production electric hypercar built around extreme acceleration and advanced technology.'),
  ('car_arden_heritage_racer','Ferrani Monza SP2',2800000,5,25,'legendary',150,450,'Ferrani','Monza SP2','Ferrari Monza SP2','Italy','collector_speedster','A limited two-seat speedster with strong collector demand and Icona-series exclusivity.'),
  ('car_lorian_hyper_gt','Koenigseg Jesko Absolut',3000000,5,27,'legendary',-100,425,'Koenigseg','Jesko Absolut','Koenigsegg Jesko Absolut','Sweden','hypercar','An extreme low-production hypercar focused on maximum speed, engineering and exclusivity.'),
  ('car_virelli_road_legend','Ferrani F40',3400000,5,30,'legendary',300,425,'Ferrani','F40','Ferrari F40','Italy','classic_supercar','A landmark analogue supercar with exceptional collector demand and strong appreciation potential.'),
  ('car_auremont_one','Pagano Utopia Roadster',3600000,5,33,'legendary',50,400,'Pagano','Utopia Roadster','Pagani Utopia Roadster','Italy','hyper_roadster','A handcrafted limited-production hyper roadster combining bespoke engineering with collector-level exclusivity.'),
  ('car_asterion_halo','Bugatta Tourbillon',4600000,5,35,'legendary',0,400,'Bugatta','Tourbillon','Bugatti Tourbillon','France','halo_hypercar','A limited-production road-going halo hypercar representing the highest tier of modern automotive prestige.')
)
update public.private_life_asset_catalog c
set
  name=u.name,
  purchase_price=u.purchase_price,
  tier=u.tier,
  prestige=u.prestige,
  rarity=u.rarity,
  description=u.description,
  annual_running_cost=greatest(1800,round(u.purchase_price*0.072)::bigint),
  annual_value_rate_bps=u.annual_value_rate_bps,
  resale_discount_bps=u.resale_discount_bps,
  metadata=jsonb_build_object(
    'brand_fictional',true,
    'fictional_brand',u.brand_name,
    'fictional_model',u.model_name,
    'real_life_inspiration',u.real_life_inspiration,
    'country_origin',u.country_origin,
    'vehicle_segment',u.vehicle_segment,
    'base_market_price',u.purchase_price,
    'market_currency','USD',
    'image_status','placeholder',
    'image_storage_folder','Private Life/Cars'
  ),
  updated_at=now()
from car_updates u
where c.code=u.code
  and c.category='car'
  and c.active=true;

-- Private Life finance is USD-only. Record that explicitly in catalog metadata as well.
update public.private_life_asset_catalog
set metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object('market_currency','USD'),
    updated_at=now()
where active=true;

do $$
declare
  v_cars integer;
  v_car_usd integer;
  v_max bigint;
  v_min bigint;
  v_accounts_non_usd integer;
  v_watch_usd integer;
  v_jewelry_usd integer;
begin
  select count(*),min(purchase_price),max(purchase_price)
    into v_cars,v_min,v_max
  from public.private_life_asset_catalog
  where category='car' and active=true;

  select count(*) into v_car_usd
  from public.private_life_asset_catalog
  where category='car' and active=true and metadata->>'market_currency'='USD';

  select count(*) into v_watch_usd
  from public.private_life_asset_catalog
  where category='watch' and active=true and metadata->>'market_currency'='USD';

  select count(*) into v_jewelry_usd
  from public.private_life_asset_catalog
  where category='jewelry' and active=true and metadata->>'market_currency'='USD';

  select count(*) into v_accounts_non_usd
  from public.player_career_finance_accounts
  where currency<>'USD';

  if v_cars<>40 then
    raise exception 'Expected 40 active car rows, found %.',v_cars;
  end if;
  if v_car_usd<>40 then
    raise exception 'Expected all 40 active cars to be USD tagged, found %.',v_car_usd;
  end if;
  if v_watch_usd<>(select count(*) from public.private_life_asset_catalog where category='watch' and active=true) then
    raise exception 'Not all active watches are USD tagged.';
  end if;
  if v_jewelry_usd<>(select count(*) from public.private_life_asset_catalog where category='jewelry' and active=true) then
    raise exception 'Not all active jewelry is USD tagged.';
  end if;
  if v_accounts_non_usd<>0 then
    raise exception 'Found % non-USD finance accounts.',v_accounts_non_usd;
  end if;
  if v_min<>6500 or v_max<>4600000 then
    raise exception 'Unexpected car price range % to %.',v_min,v_max;
  end if;
end;
$$;
