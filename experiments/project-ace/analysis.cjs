'use strict';
// Advice from elapsed observable statistics only. No opponent command or hidden skill access.
function recommendations(players,stats,side,total){
 const p=players[side],q=players[1-side],a=stats[side],b=stats[1-side],out=[];
 const add=(title,reason,patch)=>out.push({title,reason,patch});
 if(p.fatigue>=55)add('Conserve energy','Your player is tiring. Shorter points may reduce physical effort.',{rally:'Shorten points'});
 else if(q.fatigue-p.fatigue>=8&&q.fatigue>=25)add('Pressure a tiring opponent','Your opponent has at least 8 points more fatigue. Longer rallies may exploit that difference.',{rally:'Extend rallies'});
 if(a.servicePoints>=12&&a.doubleFaults>=2&&a.doubleFaults/a.servicePoints>=.08)add('Reduce double faults','Your double-fault rate is elevated. A safer serve trades power for consistency.',{serve:'Safe first serve'});
 if(b.servicePoints>=12&&b.firstIn/b.servicePoints<=.55)add('Pressure the second serve','Your opponent is landing at most 55% of first serves. More aggressive second-serve returns may help.',{returnGame:'Attack second serve'});
 if(total>=20&&a.unforcedErrors>=5&&a.unforcedErrors/total>=.16)add('Reduce unnecessary risk','Your unforced errors are accumulating. A defensive approach may improve consistency.',{approach:'Defensive'});
 return out;
}
module.exports={recommendations};

 // New model uses the same observed evidence for automatic and human coaching.
function contextualAdvice(players,stats,side,total,events,surface,weather){
 const p=players[side],q=players[1-side];
 const recent=events.filter(e=>e.kind==='point').slice(-48);
 const sample=[0,1].map(i=>({servicePoints:0,firstIn:0,doubleFaults:0,unforcedErrors:0}));
 for(const e of recent){sample[e.server].servicePoints++;if(e.first)sample[e.server].firstIn++;if(e.df)sample[e.server].doubleFaults++;if(e.ue)sample[1-e.winner].unforcedErrors++;}
 const st=recent.length>=24?sample:stats;
 const out=recommendations(players,st,side,recent.length>=24?recent.length:total);
 const add=(title,reason,patch)=>{if(!out.some(a=>Object.keys(patch).some(k=>Object.hasOwn(a.patch,k))))out.push({title,reason,patch});};
 if(p.fatigue>=50||weather?.temperatureC>=32&&p.fatigue>=35)add('Manage physical load','Current fatigue and conditions favor conserving energy.',{rally:'Shorten points'});
 if(p.fatigue>=55)add('Reduce aggression','Fatigue reduces the payoff from aggressive play.',{approach:'Defensive'});
 if(p.fatigue<=25&&p.focus>=68)add('Use early energy','Freshness and focus support an attacking approach.',{approach:'Aggressive'});
 if(p.style==='Serve & Volley'&&surface==='grass'&&p.fatigue<40)add('Use short points on grass','Your public playing style favors short points on this surface.',{rally:'Shorten points'});
 if(p.serve>=75&&p.fatigue<35)add('Use strong serving','Observed serve effectiveness and energy support power serving.',{serve:'Power serving'});
 return out;
}
module.exports.contextualAdvice=contextualAdvice;
