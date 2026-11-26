'use strict';
// Explicit local snapshot format, not a production database client.
const {adapt}=require('./profiles.cjs'),{metadata,validateWeather,environment}=require('./match-context.cjs');
const string=(x,k,max=120)=>{if(typeof x!=='string'||!x.trim()||x.length>max)throw Error('Invalid '+k);return x.trim();};
const integer=(x,k,min,max)=>{if(!Number.isInteger(x)||x<min||x>max)throw Error('Invalid '+k);return x;};
const styleMap={'All-court':'All-court','Aggressive Baseliner':'Aggressive Baseliner','Defensive Baseliner':'Defensive Baseliner','Serve & Volley':'Serve & Volley'};
const skills=['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement','fatigue','sharpness','morale','confidence','focus'];
function importSnapshot(raw){
 if(!raw||raw.schema!=='ace-legacy-snapshot-v1'||raw.match?.status!=='scheduled'||!Array.isArray(raw.players)||raw.players.length!==2)throw Error('Expected two-player scheduled snapshot');
 const m=raw.match,surface=string(m.surface,'surface').toLowerCase(),world=string(m.world,'world').toLowerCase(),category=string(m.category_code,'category');
 if(!['hard','clay','grass'].includes(surface)||!['atp','wta'].includes(world))throw Error('Invalid surface or world');
 if(!['main_draw','qualification'].includes(m.draw_type))throw Error('Unsupported draw type');
 const detail={tournament_name:string(m.tournament_name,'tournament'),city:string(m.city,'city'),country_code:string(m.country_code,'country',3),round_label:string(m.round_label,'round'),world,category_code:category,draw_type:m.draw_type,scheduled_season_week:integer(m.scheduled_season_week,'season week',1,53),scheduled_day:integer(m.scheduled_day,'day',1,7),scheduled_start_minute:integer(m.scheduled_start_minute,'start minute',0,1439),court_number:integer(m.court_number,'court',1,100)};
 if(!/^[A-Z]{2,3}$/.test(detail.country_code))throw Error('Invalid country code');
 const players=raw.players.map(({player,skills:s,equipment='standard'})=>{
  if(!player||!s||typeof player.id!=='string'||!player.id||s.player_id!==player.id)throw Error('Mismatched player and skills');
  const selected=Object.fromEntries(skills.map(k=>[k,integer(s[k],k,k==='fatigue'?0:1,100)]));
  selected.preferred_surface=string(s.preferred_surface??player.preferred_surface??'Hard','preferred surface').toLowerCase();
  const style=s.playing_style??player.playing_style??'All-court';
  if(!Object.hasOwn(styleMap,style))throw Error('Unsupported playing style');
  return {...adapt(string(player.first_name,'first name')+' '+string(player.last_name,'last name'),selected,surface),...metadata({style:styleMap[style],hand:player.playing_hand??'right',equipment})};
 });
 if(raw.players[0].player.id===raw.players[1].player.id)throw Error('Duplicate player');
 const bestOf=world==='atp'&&category==='grand_slam_2000'&&m.draw_type==='main_draw'?5:3;
 return {players,surface,bestOf,weather:raw.weather?validateWeather(raw.weather):environment(),detail};
}
module.exports={importSnapshot};
