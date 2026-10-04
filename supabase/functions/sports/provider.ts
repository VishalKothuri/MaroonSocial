// Only documented/public visitor feeds. A scheduled start never implies LIVE.
export type MarketQuote = { ticker:string; title:string; bid:number|null; ask:number|null; last:number|null; updatedAt:number; sourceURL:string };
export type SportsGame = { id:string; sport:string; sportSlug:string; opponent:string; starts:number; timeTBA:boolean; homeAway:string;
 status:string; aggieScore:number|null; opponentScore:number|null; result:string|null; sourceURL:string; trackerURL:string|null; quote:MarketQuote|null };
const safeURL=(value:unknown,hosts:string[])=>{try{const u=new URL(String(value));return u.protocol==='https:'&&!u.username&&!u.password&&hosts.includes(u.hostname)?u.href:null}catch{return null}};
const amount=(value:unknown)=>{if(value===null||value===undefined||value==='')return null;const n=Number(value);return Number.isFinite(n)&&n>=0&&n<=10000?n:null};
const epoch=(value:unknown)=>Date.parse(String(value))/1000;
export function normalizeGame(row:any):SportsGame|null {
 const sport=row.schedule?.sport; const starts=epoch(row.datetime);
 if(!Number.isSafeInteger(row.id)||!Number.isFinite(starts)||!sport?.name||!/^[a-z0-9-]+$/.test(sport.slug??'')||!row.opponent_name)return null;
 const result=row.schedule_event_result??{}; const final=row.status==='completed';
 let aggieScore=null,opponentScore=null;
 // The source's winning/losing scores are not home/away scores.
 if(final&&['win','loss','tie'].includes(result.result)) {
  aggieScore=amount(result.result==='loss'?result.losing_score:result.winning_score);
  opponentScore=amount(result.result==='loss'?result.winning_score:result.losing_score);
 }
 const tracker=(row.schedule_event_links??[]).find((x:any)=>/^live stats$/i.test(x.title??''));
 return {id:String(row.id),sport:String(sport.name).slice(0,70),sportSlug:sport.slug,opponent:String(row.opponent_name).slice(0,100),starts,
 timeTBA:!!row.is_all_day||['time_tba','date_tba','date_time_tba'].includes(row.tba),homeAway:['home','away','neutral'].includes(row.venue_type)?row.venue_type:'neutral',
 status:final?'final':row.status==='cancelled'?'cancelled':row.status==='postponed'?'postponed':'scheduled',
 aggieScore,opponentScore,result:final?String(result.result??''):null,
 sourceURL:final&&row.has_box_score?(safeURL(row.box_score_url,['12thman.com'])??`https://12thman.com/sports/${sport.slug}/schedule`):`https://12thman.com/sports/${sport.slug}/schedule`,
 trackerURL:safeURL(tracker?.link,['statb.us','stats.statbroadcast.com','www.statbroadcast.com','12thman.com']),quote:null};
}
const chicagoDate=(seconds:number)=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(seconds*1000));
export function attachFootballQuotes(games:SportsGame[],markets:any[],fetchedAt:number) {
 for(const game of games) {
  if(game.sportSlug!=='football'||game.status!=='scheduled')continue;
  // Exact winner identity excludes East Texas A&M. Match opponent and Chicago
  // day, not a fuzzy substring or a ticker assembled from guessed team codes.
  const candidates=markets.filter(m=>m.status==='active'&&m.yes_sub_title==='Texas A&M'&&m.title==='Texas A&M wins'
   && m.event_ticker?.startsWith('KXNCAAFGAME-')
   && (String(m.rules_primary??'').includes(` vs ${game.opponent} `)||String(m.rules_primary??'').includes(`${game.opponent} vs `))
   && Number.isFinite(epoch(m.occurrence_datetime))&&chicagoDate(epoch(m.occurrence_datetime))===chicagoDate(game.starts));
  if(candidates.length!==1)continue;
  const m=candidates[0];const price=(v:unknown)=>{const n=amount(v);return n!==null&&n<=1?n:null};
  const bid=price(m.yes_bid_dollars),ask=price(m.yes_ask_dollars),last=Number(m.volume_fp)>0?price(m.last_price_dollars):null;
  // A 0/1 endpoint without a resting order is not a tradable quote.
  const validBid=Number(m.yes_bid_size_fp)>0?bid:null,validAsk=Number(m.yes_ask_size_fp)>0?ask:null;
  if(validBid===null&&validAsk===null&&last===null)continue;
  if(validBid!==null&&validAsk!==null&&validBid>validAsk)continue;
  const updatedAt=epoch(m.updated_time);if(!Number.isFinite(updatedAt)||updatedAt>fetchedAt+60)continue;
  game.quote={ticker:m.ticker,title:'Texas A&M wins',bid:validBid,ask:validAsk,last,updatedAt,
   sourceURL:`https://kalshi.com/markets/kxncaafgame/${String(m.event_ticker).toLowerCase()}`};
 }
 return games;
}
export async function boundedJSON(url:string,fetcher:typeof fetch=fetch) {
 const response=await fetcher(url,{signal:AbortSignal.timeout(10000),headers:{Accept:'application/json','User-Agent':'MaroonSocial/1.0 official sports facts'}});
 if(!response.ok||Number(response.headers.get('content-length')??0)>3_000_000)throw Error('Provider unavailable');
 const reader=response.body?.getReader();if(!reader)throw Error('Empty provider response');
 const chunks:Uint8Array[]=[];let size=0;
 try {while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>3_000_000)throw Error('Provider payload too large');chunks.push(value)}}finally{await reader.cancel()}
 const data=new Uint8Array(size);let offset=0;for(const chunk of chunks){data.set(chunk,offset);offset+=chunk.length}return JSON.parse(new TextDecoder().decode(data));
}
export async function fetchSports(fetcher:typeof fetch=fetch,now=Date.now()/1000) {
 const api=(past:boolean)=>{const u=new URL('https://12thman.com/website-api/schedule-events');u.search=new URLSearchParams({[past?'filter[past]':'filter[upcoming]']:'true',sort:past?'-datetime':'datetime',include:'schedule.sport,scheduleEventLinks,scheduleEventResult',per_page:'100'}).toString();return u.href};
 const [past,next,quotes]=await Promise.allSettled([boundedJSON(api(true),fetcher),boundedJSON(api(false),fetcher),boundedJSON('https://external-api.kalshi.com/trade-api/v2/markets?series_ticker=KXNCAAFGAME&status=open&limit=1000',fetcher)]);
 if(past.status!=='fulfilled'||next.status!=='fulfilled'||!Array.isArray(past.value.data)||!Array.isArray(next.value.data))throw Error('Official scores unavailable');
 const byID=new Map<string,SportsGame>();for(const row of [...past.value.data,...next.value.data]){const game=normalizeGame(row);if(game&&game.starts>=now-21*86400&&game.starts<=now+60*86400)byID.set(game.id,game)}
 const games=[...byID.values()].sort((a,b)=>a.starts-b.starts).slice(0,200);
 const warnings:string[]=[];
 if(quotes.status==='fulfilled'&&Array.isArray(quotes.value.markets))attachFootballQuotes(games,quotes.value.markets,now);
 else warnings.push('Market quotes could not be updated.');
 return {games,fetchedAt:now,source:'Texas A&M Athletics · 12thman.com',sourceURL:'https://12thman.com',livePlayAvailable:false,warnings};
}
