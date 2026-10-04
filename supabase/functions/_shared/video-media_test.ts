import { validateMP4, sanitizeVideo } from './video-media.ts';
const u=(n:number)=>new Uint8Array([(n>>>24)&255,(n>>>16)&255,(n>>>8)&255,n&255]);
const concat=(...values:Uint8Array[])=>{const out=new Uint8Array(values.reduce((n,v)=>n+v.length,0));let at=0;for(const v of values){out.set(v,at);at+=v.length}return out};
const str=(s:string)=>new TextEncoder().encode(s);
const box=(type:string,...body:Uint8Array[])=>{const value=concat(...body);return concat(u(value.length+8),str(type),value)};
function fixture(duration=1000,codec='avc1',external=false):Uint8Array {
 const movie=new Uint8Array(100);movie.set(u(1000),12);movie.set(u(duration),16);
 const sample=new Uint8Array(78);new DataView(sample.buffer).setUint16(24,640);new DataView(sample.buffer).setUint16(26,480);
 const entry=box(codec,sample,box('avcC',new Uint8Array(8)));
 const stsd=box('stsd',u(0),u(1),entry);
 const dref=box('dref',u(0),u(1),box('url ',u(external?0:1)));
 return concat(box('ftyp',str('mp42'),u(0),str('mp42')),box('mdat',new Uint8Array(12)),box('moov',box('mvhd',movie),box('trak',box('mdia',box('minf',box('dinf',dref),box('stbl',stsd)))),box('udta',str('private-location'))));
}
function rejects(run:()=>void){let failed=false;try{run()}catch{failed=true}if(!failed)throw new Error('Expected invalid media rejection')}
Deno.test('MP4 metadata removed without shifting file offsets',()=>{const b=fixture();const before=b.length;validateMP4(b);if(b.length!==before||new TextDecoder().decode(b).includes('private-location'))throw new Error('Metadata retained or offsets shifted')});
Deno.test('duration, codec and external resource references rejected',()=>{for(const b of [fixture(61_000),fixture(1000,'hvc1'),fixture(1000,'avc1',true)])rejects(()=>validateMP4(b))});
Deno.test('truncation, malformed box sizes and oversized media rejected',()=>{const b=fixture();rejects(()=>validateMP4(b.subarray(0,b.length-1)));b.set(u(999999),0);rejects(()=>validateMP4(b));rejects(()=>validateMP4(new Uint8Array(5_000_001)))});
Deno.test('base64 input must decode to actual MP4',()=>{rejects(()=>sanitizeVideo('bad base64%'));rejects(()=>sanitizeVideo(btoa('not an mp4')))});
