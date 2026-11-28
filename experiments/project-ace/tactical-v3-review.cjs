'use strict';
// Review-only extension, not a claim of Legacy probability equivalence.
// New controls are source-informed by 20261004184000; coefficients on Ace's
// point model are explicitly bounded. Existing tactical-v2 controls stay intact.
const old=require('./tactical-v2.cjs');
const clamp=(n,l,h)=>Math.max(l,Math.min(h,n));
const raw=p=>p.rawServe??p.serve;
const options={serve:['Safe first serve','Balanced','Power serving','Serve + 1'],returnGame:['Safe return','Balanced','Attack second serve','Aggressive return'],target:['Automatic','Backhand','Forehand','Movement','Stamina','Second serve'],servePlacement:['Automatic','Wide','Body','T'],returnPosition:['Normal','Closer','Deeper'],courtPosition:['Normal baseline','Deep baseline','Inside baseline','Net attack'],risk:['Balanced','Safe','Aggressive']};
const defaults={servePlacement:'Automatic',returnPosition:'Normal',courtPosition:'Normal baseline',risk:'Balanced'};
function modifiers(p,q,t){
 let serve=0,ret=0,rally=0,ace=0,ue=0;
 if(t.servePlacement==='Wide'){serve+=p.serve*clamp((66-q.movement)*.00035,-.004,.008);if(p.hand!==q.hand)serve+=p.serve*.002;ace+=.004;}
 if(t.servePlacement==='Body'){serve+=p.serve*clamp((q.return-62)*.00025,0,.006);ue-=.002;}
 if(t.servePlacement==='T'){serve+=p.serve*clamp((raw(p)-62)*.00020,-.003,.005);ace+=.003;}
 if(t.returnPosition==='Deeper'){ret+=p.return*clamp((raw(q)-65)*.00035,-.005,.008);ue-=.002;}
 if(t.returnPosition==='Closer'){ret+=p.return*clamp((66-raw(q))*.00035,-.006,.008);ue+=.003;}
 if(t.serve==='Serve + 1'){serve+=.35;rally+=.30;ue+=.005;}
 if(t.returnGame==='Aggressive return'){ret+=.45;ue+=.006;}
 if(t.courtPosition==='Inside baseline'){ret+=.18;ue+=.005;}
 if(t.courtPosition==='Net attack'){serve+=.15;rally-=.12;ue+=.008;}
 // Deep baseline was not explicitly adjusted by the Legacy compatibility
 // wrapper; this small Ace-specific positioning effect requires calibration.
 if(t.courtPosition==='Deep baseline'){ret+=.10;rally+=.15;serve-=.10;ue-=.003;}
 if(t.risk==='Aggressive'){serve+=.20;rally+=.25;ret+=.15;ue+=.022;}
 if(t.risk==='Safe'){serve-=.15;rally+=.05;ret+=.08;ue-=.020;}
 return {serve,ret,rally,ace,ue};
}
function probabilities(s,server,first,effective){
 const a=s.players[server],b=s.players[1-server],ta=s.tactics[server],tb=s.tactics[1-server];
 // Preserve v2 contextual handedness behavior without modifying v2.
 const q=old.probabilities({...s,version:'ace-context-0.5'},server,first,effective);
 const x=modifiers(a,b,ta),y=modifiers(b,a,tb);
 // Second-serve target acts only when receiving a second serve.
 const target=!first&&tb.target==='Second serve'?clamp((65-raw(a))*.00045,-.006,.010):0;
 const delta=(first?.0045:.0038)*(.65*(x.serve-y.ret)+.35*(x.rally-y.rally))+(y.ue-x.ue)*.2-target;
 return {...q,ace:clamp(q.ace+x.ace,.003,.22),serverWin:clamp(q.serverWin+clamp(delta,-.025,.025),first?.46:.32,first?.90:.78),tacticalDelta:clamp(q.tacticalDelta+delta,-.09,.09)};
}
module.exports={options,defaults,modifiers,probabilities};
