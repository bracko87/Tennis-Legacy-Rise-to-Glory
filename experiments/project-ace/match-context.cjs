'use strict';
// Isolated adapter inspired by the existing SQL V2 style/weather and equipment modifiers.
// No inventory, injury, staff or production calls. Context is frozen at fixture creation.
const clamp=(n,l,h)=>Math.max(l,Math.min(h,n));
const climates={
 normal:{environment:'outdoor',temperatureC:21,windKmh:5,precipitation:'none'},
 hot:{environment:'outdoor',temperatureC:34,windKmh:5,precipitation:'none'},
 windy:{environment:'outdoor',temperatureC:20,windKmh:26,precipitation:'none'},
 indoor:{environment:'indoor',temperatureC:21,windKmh:0,precipitation:'none'},
 drizzle:{environment:'outdoor',temperatureC:16,windKmh:12,precipitation:'light_drizzle'}
};
const styles=['All-court','Aggressive Baseliner','Defensive Baseliner','Serve & Volley'];
const gear=['standard','performance','missing-racket','missing-shoes','missing-apparel'];
function environment(name='normal'){
 if(!Object.hasOwn(climates,name))throw Error('Invalid weather preset');
 return {...climates[name]};
}
function validateWeather(w){
 if(!w||!['outdoor','indoor'].includes(w.environment)||!Number.isFinite(w.temperatureC)||w.temperatureC<0||w.temperatureC>45||!Number.isFinite(w.windKmh)||w.windKmh<0||w.windKmh>50||!['none','light_drizzle'].includes(w.precipitation))throw Error('Invalid weather');
 if(w.environment==='indoor'&&(w.windKmh!==0||w.precipitation!=='none'))throw Error('Invalid indoor conditions');
 return {environment:w.environment,temperatureC:w.temperatureC,windKmh:w.windKmh,precipitation:w.precipitation};
}
function metadata(p){
 const style=p.style??'All-court',hand=p.hand??'right',equipment=p.equipment??'standard';
 if(!styles.includes(style)||!['left','right'].includes(hand)||!gear.includes(equipment))throw Error('Invalid match profile context');
 return {style,hand,equipment};
}
function effective(p,t,w,base){
 const x=base(p,t),m=metadata(p);
 let serve=x.serve,ret=x.ret,rally=x.rally,ue=x.ue;
 // Small style shifts; no unconditional handedness advantage.
 if(m.style==='Aggressive Baseliner'){rally=.72*rally+.28*(.48*p.forehand+.34*p.backhand+.10*p.movement+.08*p.stamina)*(x.rally/Math.max(1,p.rally));serve+=clamp((p.forehand-50)*.025,-.8,1);ue+=.010;}
 if(m.style==='Defensive Baseliner'){ret+=clamp((p.movement+p.stamina-100)*.018,-.5,1.1);serve-=.25;ue-=.010;}
 if(m.style==='Serve & Volley'){serve+=clamp(((p.rawServe??p.serve)+p.forehand-100)*.012,-.7,1.2);rally*=.995;ue+=.005;}
 const heat=w.environment==='outdoor'?clamp((w.temperatureC-25)/15,0,1):0;
 const wind=w.environment==='outdoor'?clamp((w.windKmh-7)/42,0,.45):0;
 const hp=heat*(p.fatigue/100)**1.45*Math.max(.55,1-(p.stamina-50)/160);
 const wp=wind*Math.max(.55,1-(p.focus-50)/120);
 serve*=1-hp*.035;ret*=1-hp*.045;rally*=1-hp*.055;
 serve*=1-wp*.025;ret*=1-wp*.018;rally*=1-wp*.020;ue+=wp*.018;
 if(w.precipitation==='light_drizzle'){rally*=.996;ue+=.003;}
 if(m.equipment==='performance'){serve*=1.02;ret*=1.02;rally*=1.02;}
 if(m.equipment==='missing-racket'){serve*=.65;ret*=.65;rally*=.65;}
 if(m.equipment==='missing-shoes'){ret*=.93;rally*=.93;}
 if(m.equipment==='missing-apparel'){serve*=.97;ret*=.97;rally*=.97;}
 return {...x,serve:clamp(serve,0,100),ret:clamp(ret,0,100),rally:clamp(rally,0,100),ue:clamp(ue,.04,.4),first:clamp(x.first-wp*.035-(m.equipment==='missing-racket'?.08:0),.35,.85),df:clamp(x.df+wp*.012+(m.equipment==='missing-racket'?.025:0),.004,.18)};
}
function exertion(p,w){
 const heat=w.environment==='outdoor'?clamp((w.temperatureC-25)/15,0,1):0;
 return 1+heat*.18*(1+(100-p.stamina)/200)+(p.equipment==='missing-shoes'?.08:0);
}
module.exports={environment,validateWeather,metadata,effective,exertion};
