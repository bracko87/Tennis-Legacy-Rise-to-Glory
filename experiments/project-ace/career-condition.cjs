'use strict';
// Port of calculate_match_fatigue_v2 and apply_match_condition_effects_v1,
// using the newer simulated_tennis_duration_minutes_v1 game-duration formula.
// Temporary point-by-point fatigue is not charged a second time.
const clamp=(n,l,h)=>Math.max(l,Math.min(h,n));
function apply(profile,result,won,surface){
 const minutes=clamp(Math.round(result.totalGames*5+result.totalPoints*.13),60,420);
 const sets=result.sets.length,games=result.totalGames;
 const p=profile;
 let base=minutes<=70&&sets===2?6:minutes<=105&&sets===2?8:minutes<=145?11:minutes<=205?15:minutes<=285?19:23;
 base+=games>=45?3:games>=36?2:games>=30?1:0;
 if(sets>=4)base+=2*(sets-3);
 const surfaceFactor=surface==='clay'?1.08:surface==='grass'?.95:1;
 const gain=clamp(Math.round(base*surfaceFactor*(1.12-.24*(p.fitness+p.stamina)/200)*(1.10-.20*p.recovery/100)),4,28);
 const before=Object.fromEntries(['fatigue','sharpness','morale','confidence','focus'].map(k=>[k,p[k]]));
 const after={fatigue:clamp(p.fatigue+gain,0,100),sharpness:clamp(p.sharpness+(minutes>=150?1:2),1,100),morale:clamp(p.morale+(won?1:-1),1,100),confidence:clamp(p.confidence+(won?3:-1),1,100),focus:clamp(p.focus+(won&&minutes<150?1:minutes>=180?-1:0),1,100)};
 return {before,after,gain,minutes};
}
module.exports={apply};
