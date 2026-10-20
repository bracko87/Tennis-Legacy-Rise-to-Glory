// INDEPENDENT deterministic match-scoring PROXY for v3 candidate calibration.
// DOES NOT call production RPCs and does not modify real matches.
// Full database-engine smoke test: tests/serve_realism_v3_db_smoke.sql
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'

const clip=(n,low,high)=>Math.max(low,Math.min(high,n))
function rnd(seed,n){
  return parseInt(createHash('md5').update(seed+':'+n).digest('hex').slice(0,8),16)/4294967296
}
function profile(seed,side,world,surface,tier){
  const r=n=>rnd(seed+':profile:'+side,n)
  const strength=tier==='elite'?67:42
  const serve=clip(strength+(r(1)-.5)*36,18,97)
  const ret=clip(strength+(r(2)-.5)*36,18,97)
  const focus=clip(70+r(3)*30,40,100), fatigue=r(4)*85
  const style=r(5)>.75?'serve-volley':r(5)<.24?'defensive':'all-court'
  const risk=r(6)>.75?'aggressive':r(6)<.24?'safe':'balanced'
  return {side,world,surface,serve,ret,focus,fatigue,style,risk,
    aceDelta:risk==='aggressive'?.018:risk==='safe'?-.010:0,
    dfDelta:risk==='aggressive'?.010:risk==='safe'?-.008:0,
    firstDelta:risk==='aggressive'?-.035:risk==='safe'?.040:0}
}
function first(p){
  return clip(clip(.54+p.serve*.002+p.focus*.0007-p.fatigue*.0004,.50,.75)+p.firstDelta,.47,.78)
}
function ace2(p,o){
  return clip(.025+(p.serve-o.ret)*.0015+({grass:.025,clay:-.008,hard:.006}[p.surface])+p.aceDelta,.003,.20)
}
function df2(p){
  return clip(.055+Math.max(0,55-p.serve)*.0011-Math.max(0,p.serve-55)*.00035+
    p.fatigue*.00028-p.focus*.00017+p.dfDelta,.02,.13)
}
function ace3(p,o){
  return clip(ace2(p,o)+(p.world==='ATP'?.041:.023)+
    clip((p.serve-43)*.0004,-.014,.023)+(p.style.includes('serve')?.005:0),.006,.205)
}
function df3(p){
  return clip(df2(p)+(p.world==='ATP'?.027:.035)+
    (p.risk==='aggressive'?.005:p.risk==='safe'?-.003:0),.015,.17)
}
function simulate(seed,world,surface,tier,newModel){
  const players=[profile(seed,0,world,surface,tier),profile(seed,1,world,surface,tier)]
  const m={idx:1,aces:[0,0],df:[0,0],firstIn:[0,0],firstWon:[0,0],
    second:[0,0],secondWon:[0,0],serves:[0,0],points:[0,0],
    breakChance:[0,0],breakWon:[0,0],games:0,sets:0,winner:-1}
  function point(serv){
    const p=players[serv],o=players[1-serv]
    m.serves[serv]++
    const inFirst=rnd(seed,m.idx++)<first(p)
    if(inFirst){
      m.firstIn[serv]++
      if(rnd(seed,m.idx++)<(newModel?ace3(p,o):ace2(p,o))){
        m.aces[serv]++;m.firstWon[serv]++;m.points[serv]++;return serv
      }
      const odds=clip(.67+.0045*(p.serve-o.ret)+({grass:.035,clay:-.02,hard:.005}[surface]),.5,.88)
      const won=rnd(seed,m.idx++)<odds?serv:1-serv
      if(won===serv)m.firstWon[serv]++
      m.points[won]++;return won
    }
    m.second[serv]++
    if(rnd(seed,m.idx++)<(newModel?df3(p):df2(p))){
      m.df[serv]++;m.points[1-serv]++;return 1-serv
    }
    const odds=clip(.52+.0038*(p.serve-o.ret)+({grass:.035,clay:-.02,hard:.005}[surface])*.5,.38,.72)
    const won=rnd(seed,m.idx++)<odds?serv:1-serv
    if(won===serv)m.secondWon[serv]++
    m.points[won]++;return won
  }
  const sets=[0,0]
  let next=rnd(seed,m.idx++)<.5?0:1
  while(sets[0]<2&&sets[1]<2){
    const games=[0,0]
    let gameCount=0
    while(true){
      if(++gameCount>35)throw Error('Set exceeded game limit')
      const score=[0,0],serv=next,receiver=1-serv
      while(true){
        const bp=score[receiver]>=3&&score[receiver]-score[serv]>=1
        if(bp)m.breakChance[receiver]++
        const won=point(serv)
        if(bp&&won===receiver)m.breakWon[receiver]++
        score[won]++
        if(Math.max(...score)>=4&&Math.abs(score[0]-score[1])>=2){
          games[won]++;break
        }
      }
      m.games++;next=1-next
      if(Math.max(...games)>=6&&Math.abs(games[0]-games[1])>=2){
        sets[games[0]>games[1]?0:1]++;break
      }
      if(games[0]===6&&games[1]===6){
        const tb=[0,0],initial=next
        let idx=0
        while(true){
          const server=idx===0?initial:(Math.floor((idx-1)/2)%2===0?1-initial:initial)
          const won=point(server);tb[won]++
          if(Math.max(...tb)>=7&&Math.abs(tb[0]-tb[1])>=2){
            sets[tb[0]>tb[1]?0:1]++;break
          }
          if(++idx>150)throw Error('Tiebreak exceeded 150 points')
        }
        m.games++;next=1-initial;break
      }
    }
    m.sets++
  }
  m.winner=sets[0]>sets[1]?0:1
  for(let i=0;i<2;i++){
    assert(m.aces[i]<=m.firstIn[i])
    assert(m.firstWon[i]<=m.firstIn[i])
    assert(m.df[i]<=m.second[i])
    assert(m.secondWon[i]<=m.second[i])
    assert.equal(m.firstIn[i]+m.second[i],m.serves[i])
  }
  assert.equal(m.points[0]+m.points[1],m.serves[0]+m.serves[1])
  return m
}
const cases=[]
const N=420
for(const world of ['ATP','WTA'])for(const surface of ['hard','clay','grass'])
for(const tier of ['elite','futures']){
  const outcome=[[],[]]
  for(let i=0;i<N;i++){
    const seed='tennis-serve-v3:'+world+':'+surface+':'+tier+':'+i
    outcome[0].push(simulate(seed,world,surface,tier,false))
    outcome[1].push(simulate(seed,world,surface,tier,true))
  }
  const avg=(arr,fn)=>arr.reduce((total,m)=>total+fn(m),0)/arr.length
  const calc=(arr)=>({
    aces:avg(arr,m=>m.aces[0]+m.aces[1])/2,
    df:avg(arr,m=>m.df[0]+m.df[1])/2,
    games:avg(arr,m=>m.games),
    breakWon:avg(arr,m=>m.breakWon[0]+m.breakWon[1])/2,
    firstInPct:100*arr.reduce((s,m)=>s+m.firstIn[0]+m.firstIn[1],0)/
      arr.reduce((s,m)=>s+m.serves[0]+m.serves[1],0),
    zeroAcePct:50*avg(arr,m=>(m.aces[0]===0?1:0)+(m.aces[1]===0?1:0))
  })
  const baseline=calc(outcome[0]),candidate=calc(outcome[1])
  assert(candidate.aces>baseline.aces)
  assert(candidate.df>baseline.df)
  assert(Math.abs(candidate.games-baseline.games)<5)
  assert(candidate.firstInPct>50&&candidate.firstInPct<80)
  assert(candidate.aces<15&&candidate.df<11)
  cases.push({world,surface,tier,count:N,baseline,candidate,
    winnerFlips:outcome[0].filter((r,i)=>r.winner!==outcome[1][i].winner).length})
}
function mean(world,version,metric){
  return cases.filter(c=>c.world===world).reduce((s,c)=>s+c[version][metric],0)/6
}
assert(mean('ATP','candidate','aces')>mean('WTA','candidate','aces'))
const winnerChanges=Object.fromEntries(
  ['ATP','WTA'].map(world=>{
    const group=cases.filter(c=>c.world===world)
    const changed=group.reduce((sum,c)=>sum+c.winnerFlips,0)
    const sample=group.reduce((sum,c)=>sum+c.count,0)
    return [world,{changed,sample,ratePct:Number((100*changed/sample).toFixed(2))}]
  })
)
const overallWinnerChanges={
  changed:Object.values(winnerChanges).reduce((sum,x)=>sum+x.changed,0),
  sample:cases.length*N,
}
overallWinnerChanges.ratePct=Number((100*overallWinnerChanges.changed/overallWinnerChanges.sample).toFixed(2))
assert.equal(overallWinnerChanges.sample,5040)
const summary=['ATP','WTA'].map(world=>({world,...Object.fromEntries(
  ['aces','df','games','breakWon','firstInPct','zeroAcePct']
    .map(metric=>[metric,{
      baseline:Number(mean(world,'baseline',metric).toFixed(2)),
      candidate:Number(mean(world,'candidate',metric).toFixed(2))
    }]))}))
console.log(JSON.stringify({simulation:'independent fixed-seed point-scoring proxy, NOT official database engine',
  seed:'tennis-serve-v3',cases:cases.length,perCase:N,totalMatches:cases.length*N,summary,winnerChanges,overallWinnerChanges,casesBySurface:cases},null,2))
