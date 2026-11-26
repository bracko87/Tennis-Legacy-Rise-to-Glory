'use strict';
// Existing get_game_clock_v1 output contract. No network access.
const DAY=86400,SEASON=366;
const int=(x,min,max)=>{if(!Number.isSafeInteger(x)||x<min||x>max)throw Error('Invalid calendar value');return x;};
function sample(raw){
 const realMs=typeof raw.server_now==='string'?Date.parse(raw.server_now):NaN;
 const gameSeconds=Number(raw.game_total_seconds),speed=Number(raw.speed_multiplier);
 if(raw.game_total_seconds==null||raw.speed_multiplier==null||!Number.isSafeInteger(realMs)||realMs<0||!Number.isSafeInteger(gameSeconds)||gameSeconds<0||!Number.isFinite(speed)||speed<0||speed>1000)throw Error('Invalid game clock sample');
 return {realMs,gameSeconds,speed};
}
function at(c,now){int(now,c.realMs,Number.MAX_SAFE_INTEGER);return int(c.gameSeconds+Math.floor((now-c.realMs)*c.speed/1000),0,Number.MAX_SAFE_INTEGER);}
function slot(season,week,day,minute=600){
 int(season,1,10000);int(week,1,52);int(day,1,7);int(minute,0,1439);
 return ((season-1)*SEASON+2+(week-1)*7+day-1)*DAY+minute*60;
}
function mondayAfterPhase(season,lastWeek){return slot(season,lastWeek,1,0)/DAY+7;}
function nextMonday(day){int(day,0,Number.MAX_SAFE_INTEGER);for(let d=day;d<day+10;d++)if((d%SEASON-2)%7===0&&d%SEASON>=2)return d;throw Error('Calendar error');}
module.exports={DAY,SEASON,sample,at,slot,mondayAfterPhase,nextMonday};
