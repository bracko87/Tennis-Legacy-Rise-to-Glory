'use strict';
// Reproduces CALIBRATION_V05.json using the actual isolated engine. No external dependencies.
const e=require('./engine.cjs'),p=require('./profiles.cjs'),ctx=require('./match-context.cjs'),a=require('./analysis.cjs');
const finish=(s,auto=false)=>{while(s.status!=='completed'){if(auto){const o=e.observable(s);const patch={approach:'Balanced',rally:'Balanced rallies',serve:'Balanced',returnGame:'Balanced',target:'Automatic'};for(const item of a.contextualAdvice(o.players,o.stats,0,o.totalPoints,o.events,s.surface,s.weather))Object.assign(patch,item.patch);s=e.queueTactics(s,0,patch);}s=e.stepGame(s);}return s;};
const N=60,rows=[];
for(const surface of ['hard','clay','grass'])for(const gap of [0,12,28]){
 let wins=0,points=0,first=0,aces=0,dfs=0,fat=0,games=0;
 for(let i=1;i<=N;i++){
  const ps=p.fixtureProfiles('balanced','balanced',surface,false,{});
  for(const k of ['serve','return','rally','forehand','backhand','rawServe'])ps[0][k]=Math.min(100,ps[0][k]+gap);
  const s=finish(e.createMatch({players:ps,surface,version:'ace-context-0.5',seed:Math.imul(i,2654435761)>>>0}));
  wins+=s.winner===0;points+=s.totalPoints;first+=s.stats[0].firstIn+s.stats[1].firstIn;aces+=s.stats[0].aces+s.stats[1].aces;dfs+=s.stats[0].doubleFaults+s.stats[1].doubleFaults;fat+=s.players[0].fatigue;games+=s.gameNumber;
 }
 rows.push({surface,gap,wins,N,first:Math.round(first/points*1000)/10,aces:Math.round(aces/points*1000)/10,df:Math.round(dfs/points*1000)/10,fatigue:Math.round(fat/N*10)/10,games:Math.round(games/N*10)/10});
}
let aiWins=0,baseWins=0,flips=0;
for(let i=1;i<=N;i++){
 const s=e.createMatch({players:p.fixtureProfiles('power','defensive','grass',false,{}),surface:'grass',version:'ace-context-0.5',seed:Math.imul(i,2246822519)>>>0,weather:ctx.environment('hot')});
 const c=finish(s),d=finish(s,true);baseWins+=c.winner===0;aiWins+=d.winner===0;flips+=c.winner!==d.winner;
}
const report={N,rows,auto:{N,baseWins,aiWins,flips}};
if(process.argv.includes('--verify')){require('node:assert/strict').deepEqual(report,require('./CALIBRATION_V05.json'));console.log('PASS reproducible 660-match calibration snapshot');}
else console.log(JSON.stringify(report,null,2));
