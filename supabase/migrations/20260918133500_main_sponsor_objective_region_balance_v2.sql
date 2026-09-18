create or replace function public.sponsor_category_realistic_for_rank_v2(p_rank integer,p_category text)
returns boolean
language sql
immutable
as $function$
  select case
    when coalesce(p_rank,9999)<=30 then lower(coalesce(p_category,'')) in (
      'grand_slam_2000','masters_1000','tour_500','tour_250'
    )
    when p_rank<=100 then lower(coalesce(p_category,'')) in (
      'grand_slam_2000','masters_1000','tour_500','tour_250',
      'challenger_125','challenger_100','challenger_75'
    )
    when p_rank<=300 then lower(coalesce(p_category,'')) in (
      'tour_250','challenger_125','challenger_100','challenger_75','futures_25'
    )
    when p_rank<=1000 then lower(coalesce(p_category,'')) in (
      'challenger_125','challenger_100','challenger_75','challenger_50','futures_25','futures_15'
    )
    else lower(coalesce(p_category,'')) in (
      'challenger_75','challenger_50','futures_25','futures_15'
    )
  end;
$function$;

revoke all on function public.sponsor_category_realistic_for_rank_v2(integer,text)
from public,anon,authenticated;
