/** Bounded, self-contained MP4 only. Metadata is blanked in-place so chunk
 * offsets remain valid; private upload/read authorization lives in the gateway. */
export class VideoMediaError extends Error {}
type Box={type:string,start:number,end:number,body:number};
export function sanitizeVideo(input:string):{bytes:Uint8Array,kind:'video',mime:'video/mp4'} {
 if(typeof input!=='string'||input.length>6_700_000)throw new VideoMediaError('Choose a compressed video smaller than 5 MB.');
 let bytes:Uint8Array;try{bytes=Uint8Array.from(atob(input),c=>c.charCodeAt(0))}catch{throw new VideoMediaError('This video could not be read.')}
 validateMP4(bytes);return{bytes,kind:'video',mime:'video/mp4'};
}
export function validateMP4(bytes:Uint8Array):void {
 const fail=()=>{throw new VideoMediaError('Choose a valid MP4 video up to 60 seconds, 720p, and 5 MB.');};
 if(bytes.length<32||bytes.length>5_000_000)fail();
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);let count=0;
 const text=(at:number)=>String.fromCharCode(...bytes.subarray(at,at+4));
 const u32=(at:number)=>{if(at<0||at+4>bytes.length)fail();return view.getUint32(at)};
 const u64=(at:number)=>{if(at<0||at+8>bytes.length)fail();const v=Number(view.getBigUint64(at));if(!Number.isSafeInteger(v))fail();return v};
 const boxes=(from:number,end:number):Box[]=>{
  const result:Box[]=[];let at=from;
  while(at<end){if(++count>5000||at+8>end)fail();let length=u32(at),header=8;if(length===1){length=u64(at+8);header=16}if(length===0)length=end-at;
   if(length<header||at+length>end)fail();result.push({type:text(at+4),start:at,end:at+length,body:at+header});at+=length;}
  return result;
 };
 const top=boxes(0,bytes.length);
 if(top[0]?.type!=='ftyp'||top.filter(b=>b.type==='moov').length!==1||!top.some(b=>b.type==='mdat'))fail();
 const ftyp=top[0];if(ftyp.end-ftyp.body<8||!['isom','iso2','mp41','mp42','avc1','M4V '].includes(text(ftyp.body)))fail();
 const ranges=top.filter(b=>b.type==='mdat').map(b=>[b.body,b.end]);
 let videos=0,audio=0,movieDuration=0;
 const scrub=(b:Box)=>{bytes.set([102,114,101,101],b.start+4);bytes.fill(0,b.body,b.end)};
 const descend=(nodes:Box[],depth:number)=>{
  if(depth>8)fail();
  for(const b of nodes){
   if(['udta','meta','uuid','xml '].includes(b.type)){scrub(b);continue}
   if(['moof','mvex','sinf','pssh','encv','enca'].includes(b.type))fail();
   if(['moov','trak','mdia','minf','stbl','dinf','edts'].includes(b.type)){descend(boxes(b.body,b.end),depth+1);continue}
   if(b.type==='mvhd'||b.type==='mdhd'){
    const version=bytes[b.body];if(version>1)fail();const at=b.body+(version?20:12);if(at+(version?12:8)>b.end)fail();
    const scale=u32(at),duration=version?u64(at+4):u32(at+4);if(!scale||!Number.isFinite(duration/scale)||duration/scale>60.5)fail();
    if(b.type==='mvhd')movieDuration=duration/scale;
   }
   if(b.type==='stsd'){
    if(b.body+8>b.end)fail();const entries=boxes(b.body+8,b.end);if(entries.length!==u32(b.body+4)||entries.length!==1)fail();
    for(const entry of entries){
     if(entry.type==='avc1'){
      videos++;if(entry.body+78>entry.end)fail();const w=view.getUint16(entry.body+24),h=view.getUint16(entry.body+26);
      if(!w||!h||Math.max(w,h)>1280||w*h>921600)fail();
      const children=boxes(entry.body+78,entry.end);if(!children.some(c=>c.type==='avcC'&&c.end-c.body>=7))fail();descend(children,depth+1);
     }else if(entry.type==='mp4a'){audio++;if(entry.body+28>entry.end)fail();descend(boxes(entry.body+28,entry.end),depth+1)}
     else fail();
    }
   }
   if(b.type==='dref'){
    if(b.body+8>b.end)fail();const entries=boxes(b.body+8,b.end);if(entries.length!==u32(b.body+4)||entries.length!==1)fail();
    if(entries[0].type!=='url '||entries[0].end-entries[0].body!==4||u32(entries[0].body)!==1)fail();
   }
   if(b.type==='stco'||b.type==='co64'){
    if(b.body+8>b.end)fail();const n=u32(b.body+4),stride=b.type==='co64'?8:4;if(n>100000||b.body+8+n*stride!==b.end)fail();
    for(let i=0;i<n;i++){const at=b.body+8+i*stride;const offset=stride===8?u64(at):u32(at);if(!ranges.some(([start,end])=>offset>=start&&offset<end))fail()}
   }
  }
 };
 descend(top,0);if(videos!==1||audio>1||movieDuration<=0)fail();
}
