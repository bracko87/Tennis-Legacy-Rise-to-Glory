'use strict';
// Port of get_match_engine_profile_v1 rating weights, migration 20260904145237.
// Synthetic skills only. No network or production reads.
const keys=['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement','fatigue','sharpness','morale','confidence','focus'];
const round=n=>Math.round(n*100)/100;
const weights={hard:{forehand:.29,backhand:.25,movement:.18,stamina:.08,fitness:.07,volley:.04,slice:.03,drop_shot:.02,lob:.02,smash:.02},clay:{forehand:.25,backhand:.22,movement:.23,stamina:.12,fitness:.08,drop_shot:.04,slice:.03,lob:.03},grass:{forehand:.25,backhand:.20,movement:.15,volley:.13,slice:.08,serve:.07,smash:.05,stamina:.04,fitness:.03}};
const sum=(s,w)=>Object.entries(w).reduce((n,[k,v])=>n+s[k]*v,0);
function adapt(name,s,surface='hard'){
 if(typeof name!=='string'||!name.trim()||!Object.hasOwn(weights,surface)||!s||keys.some(k=>!Number.isFinite(s[k])||s[k]<0||s[k]>100)||!Object.hasOwn(weights,s.preferred_surface))throw Error('Invalid player profile');
 const serve=round(sum(s,{serve:.62,forehand:.14,backhand:.08,volley:.06,smash:.05,movement:.05}));
 const ret=round(sum(s,{return_skill:.50,movement:.18,forehand:.13,backhand:.13,slice:.03,lob:.03}));
 return {name,serve,return:ret,rally:round(sum(s,weights[surface])),forehand:s.forehand,backhand:s.backhand,fitness:s.fitness,stamina:s.stamina,recovery:s.recovery,movement:s.movement,fatigue:s.fatigue,focus:s.focus,confidence:s.confidence,rawServe:s.serve,sharpness:s.sharpness,morale:s.morale,surfaceMultiplier:s.preferred_surface===surface?1.015:.995};
}
const common={serve:64,forehand:65,backhand:55,return_skill:58,volley:54,slice:57,drop_shot:49,lob:51,smash:56,fitness:65,stamina:68,recovery:62,movement:62,fatigue:10,sharpness:75,morale:70,confidence:70,focus:75,preferred_surface:'hard'};
const presets={
 balanced:common,
 aggressive:{...common,serve:69,forehand:77,backhand:67,return_skill:61,stamina:61,movement:66},
 defensive:{...common,serve:56,return_skill:70,forehand:60,backhand:66,stamina:79,movement:73,preferred_surface:'clay'},
 power:{...common,serve:82,forehand:76,backhand:49,volley:69,smash:73,stamina:52,movement:55,preferred_surface:'grass'}
};
function fixtureProfiles(first='balanced',second='balanced',surface='hard',human=false,settings=null){
 if(!Object.hasOwn(presets,first)||!Object.hasOwn(presets,second))throw Error('Unknown profile preset');
 const players=[adapt('Ace Admin',presets[first],surface),adapt(human?'Ace Human Peer':'Ace Test AI',presets[second],surface)];
 if(settings){const styleFor=x=>x==='defensive'?'Defensive Baseliner':x==='power'?'Serve & Volley':x==='aggressive'?'Aggressive Baseliner':'All-court';
 players.forEach((p,i)=>Object.assign(p,{style:styleFor([first,second][i]),hand:settings.hands?.[i]??'right',equipment:settings.equipment?.[i]??'standard'}));}
 return players;
}
module.exports={adapt,fixtureProfiles};
