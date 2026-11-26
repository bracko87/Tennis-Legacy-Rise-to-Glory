'use strict';
// Versioned tactical model; adjustments are bounded and symmetrical by side.
// Probabilities refer to non-ace/non-double-fault points.
const clamp=(n,l,h)=>Math.max(l,Math.min(h,n));
const neutral={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'};
const tech=p=>(p.forehand+p.backhand+p.rally)/3;
const raw=p=>p.rawServe??p.serve;
function approach(p,q,t){
 if(t.approach==='Aggressive')return clamp(.012+.0011*(tech(p)-60)+.00035*(p.focus-70)-.00045*(p.fatigue-10),-.035,.04);
 if(t.approach==='Defensive')return clamp(.005+.0007*((p.return+p.stamina)/2-62)+.00045*(p.fatigue-10)+.0005*(tech(q)-tech(p)),-.025,.032);
 return 0;
}
function rally(p,q,t,surface){
 const edge=.0012*(p.rally-q.rally)+.0009*(q.fatigue-p.fatigue)+.00055*(p.stamina-q.stamina);
 if(t.rally==='Extend rallies')return clamp(edge+(surface==='clay'?.004:surface==='grass'?-.004:0),-.04,.05);
 if(t.rally==='Shorten points')return clamp(-.65*edge+.001*(Math.max(p.serve,p.forehand)-p.rally-5)+(surface==='grass'?.005:surface==='clay'?-.003:0),-.035,.035);
 return 0;
}
function target(p,q,t){
 if(t.target==='Backhand'||t.target==='Forehand')return clamp(.0048*((q.forehand+q.backhand)/2-q[t.target.toLowerCase()]),-.04,.04);
 if(t.target==='Movement')return clamp(.0014*(62-q.movement*(1-q.fatigue*.002)),-.025,.035);
 if(t.target==='Stamina')return clamp(.001*(60-q.stamina)+.00045*(q.fatigue-p.fatigue),-.03,.04);
 return 0;
}
function serve(p,t,first){
 if(t.serve==='Power serving')return clamp((first?.018:.009)+.0012*(raw(p)-65)-.00035*(p.fatigue-10),-.025,.04);
 if(t.serve==='Safe first serve')return clamp((first?-.012:-.006)+.0005*(p.fatigue-10)+.0007*(60-raw(p)),-.035,.025);
 return 0;
}
function ret(p,q,t,first){
 if(t.returnGame==='Attack second serve')return first?0:clamp(.025+.001*(p.return-60)+.0008*(65-raw(q))-.00035*(p.fatigue-10),-.02,.06);
 if(t.returnGame==='Safe return')return clamp(.008+.00065*(raw(q)-65)+.00045*(p.fatigue-10)-.00045*(p.return-60),-.025,.028);
 return 0;
}
function probabilities(s,server,first,effective){
 const a=s.players[server],b=s.players[1-server],ta=s.tactics[server],tb=s.tactics[1-server];
 const x=effective(a,neutral),y=effective(b,neutral);
 const power=ta.serve==='Power serving'?1:ta.serve==='Safe first serve'?-1:0;
 const surface=s.surface==='grass'?.035:s.surface==='clay'?-.020:.005;
 const diff=.65*(x.serve-y.ret)+.35*(x.rally-y.rally);
 const base=(first?.67:.52)+(first?.0045:.0038)*diff+surface*(first?1:.5)+(y.ue-x.ue)*.2;
 const contribution=approach(a,b,ta)-approach(b,a,tb)+rally(a,b,ta,s.surface)-rally(b,a,tb,s.surface)+target(a,b,ta)-target(b,a,tb)+serve(a,ta,first)-ret(b,a,tb,first);
 const tacticalDelta=clamp(contribution,-.065,.065);
 const firstIn=clamp(x.first-.04*power,.45,.80);
 const doubleFault=clamp(x.df+.012*power,.004,.15);
 const ace=clamp(.025+(x.serve-y.ret)*.0015+(s.surface==='grass'?.025:s.surface==='clay'?-.008:.006)+.018*power,.003,.22);
 return {firstIn,doubleFault,ace,serverWin:clamp(base+tacticalDelta,first?.46:.32,first?.90:.78),tacticalDelta};
}
function exertion(p,q,t,oppT,long,special){
 if(special)return 1;
 let m=1;
 if(t.approach==='Aggressive')m+=.12;
 if(t.approach==='Defensive')m+=long?.04:-.04;
 if(t.rally==='Shorten points')m-=.06;
 if(t.rally==='Extend rallies')m+=.04;
 if(oppT.target==='Movement')m+=clamp(.08+.002*(60-p.movement),.02,.16);
 if(oppT.target==='Stamina'&&long)m+=clamp(.08+.002*(60-p.stamina),.02,.16);
 return clamp(m,.8,1.4);
}
module.exports={probabilities,exertion};
