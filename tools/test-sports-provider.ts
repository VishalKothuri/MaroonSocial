import {normalizeGame,attachFootballQuotes,fetchSports,boundedJSON} from '../supabase/functions/sports/provider.ts';
function assert(value:unknown,message:string){if(!value)throw Error(message)}
const base={id:1,datetime:'2026-10-03T23:00:00Z',opponent_name:'Arkansas',venue_type:'away',status:'completed',schedule:{sport:{name:'Football',slug:'football'}},schedule_event_result:{result:'loss',winning_score:'34.0000',losing_score:'7.0000'},schedule_event_links:[]};
Deno.test('Official winner scores map to Aggies by outcome, never home position or inferred LIVE',()=>{
 const loss=normalizeGame(base)!;assert(loss.aggieScore===7&&loss.opponentScore===34,'Loss reversed winner and Aggie score');
 const future=normalizeGame({...base,status:'as_scheduled'})!;assert(future.status==='scheduled'&&future.aggieScore===null,'Past schedule inferred live score');
 const hostile=normalizeGame({...base,schedule_event_links:[{title:'Live Stats',link:'https://statb.us@evil.invalid/x'}]})!;
 assert(hostile.trackerURL===null,'Credential URL passed allowlist');
 assert(normalizeGame({...base,datetime:'invalid'})===null,'Bad source date passed');
});
Deno.test('Market pairing requires exact Texas A&M, opponent and date; quote endpoints need resting size',()=>{
 const game=normalizeGame({...base,status:'as_scheduled'})!;
 const quote={status:'active',yes_sub_title:'Texas A&M',title:'Texas A&M wins',rules_primary:'If Texas A&M wins the Texas A&M vs Arkansas college football game',event_ticker:'KXNCAAFGAME-26OCT03ARKTXAM',ticker:'KXNCAAFGAME-26OCT03ARKTXAM-TXAM',occurrence_datetime:'2026-10-04T02:00:00Z',yes_bid_dollars:'0.72',yes_ask_dollars:'1.00',yes_bid_size_fp:'150',yes_ask_size_fp:'0',volume_fp:'400',last_price_dollars:'0.71',updated_time:'2026-10-03T22:00:00Z'};
 const now=Date.parse('2026-10-04T12:00:00Z')/1000;
 attachFootballQuotes([game],[quote],now);assert(game.quote?.bid===0.72&&game.quote?.ask===null,'Nonresting 1.00 ask shown');
 for(const wrong of [{...quote,yes_sub_title:'East Texas A&M'},{...quote,occurrence_datetime:'2026-10-11T02:00:00Z'},{...quote,rules_primary:'Texas A&M vs Missouri college football game'}]){
  const other={...game,quote:null};attachFootballQuotes([other],[wrong],now);assert(other.quote===null,'Mismatched event inherited quote');
 }
 const ambiguous={...game,quote:null};attachFootballQuotes([ambiguous],[quote,quote],now);assert(ambiguous.quote===null,'Ambiguous pair should not guess');
});
Deno.test('Provider failure cannot fabricate sports data; optional market outage preserves official result',async()=>{
 const fetcher=((url:string|URL|Request)=>Promise.resolve(String(url).includes('kalshi')?new Response('offline',{status:503}):Response.json({data:[base]}))) as typeof fetch;
 const snapshot=await fetchSports(fetcher,Date.parse('2026-10-04T12:00:00Z')/1000);
 assert(snapshot.games.length===1&&snapshot.warnings.length===1,'Deduplication or optional outage failed');
 assert(snapshot.livePlayAvailable===false,'Unavailable ball data claimed available');
 let failed=false;try{await boundedJSON('https://fixture.invalid',async()=>new Response('x'.repeat(3_000_001)))}catch{failed=true}
 assert(failed,'Unbounded provider response accepted');
});
