'use strict';
// Core equipment wear formula from 20260915162006. Bag protection is resolved by the exporter.
const finite=(x,l,h)=>{if(typeof x!=='number'||!Number.isFinite(x)||x<l||x>h)throw Error('Invalid catalogue wear');return x;};
function wearUnits(inventory,loadout,surface,bagProtectionPct=0){
 if(!['hard','clay','grass'].includes(surface))throw Error('Invalid wear surface');
 finite(bagProtectionPct,0,35);
 for(const i of inventory){finite(i.wear_per_match,.01,100);if(i.type==='shoes'){if(!['all','hard','clay','grass'].includes(i.surface))throw Error('Invalid shoe surface');finite(i.wrong_surface_wear_multiplier,1,4);}}
 const result={};
 for(const type of ['racket','shoes','apparel']){
  const i=inventory.find(x=>x.id===loadout[type]&&x.type===type&&x.condition>0);
  if(!i)continue;
  const factor=type==='racket'?1-bagProtectionPct/100:type==='shoes'?(i.surface===surface?1:i.surface==='all'?1.15:i.wrong_surface_wear_multiplier):1;
  // Wear above remaining condition has exactly the same result as 100.
  result[type]=Math.min(100,i.wear_per_match*factor);
 }
 return result;
}
module.exports={wearUnits};
