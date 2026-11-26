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
