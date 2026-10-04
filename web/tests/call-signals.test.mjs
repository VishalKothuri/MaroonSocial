import test from 'node:test';
import assert from 'node:assert/strict';
import {CallSignalBuffer} from '../public/call-signals.js';

test('offer and candidates received during camera permission survive start and keep order',async()=>{
 const buffer=new CallSignalBuffer(),received=[];
 buffer.add({id:1,kind:'offer',payload:'sdp'});buffer.add({id:2,kind:'ice',payload:'candidate'});
 assert.equal(received.length,0);
 buffer.ready(buffer.version,async value=>received.push(value));await buffer.chain;
 assert.deepEqual(received,[{type:'offer',payload:'sdp'},{type:'ice',payload:'candidate'}]);
 buffer.add({id:1,kind:'offer',payload:'sdp'});await buffer.chain;assert.equal(received.length,2);
});
test('ending while camera prompt is open cannot deliver old signals into a new session',async()=>{
 const buffer=new CallSignalBuffer(),old=buffer.version,received=[];
 buffer.add({id:1,kind:'offer',payload:'old'});buffer.reset();
 buffer.ready(old,async value=>received.push(value));
 buffer.add({id:1,kind:'offer',payload:'new'});await buffer.chain;assert.equal(received.length,0);
 buffer.ready(buffer.version,async value=>received.push(value));await buffer.chain;
 assert.deepEqual(received,[{type:'offer',payload:'new'}]);
});
test('reset interrupts a drain already awaiting the preceding signal',async()=>{
 const buffer=new CallSignalBuffer(),received=[];let release;
 buffer.add({id:1,kind:'offer',payload:'first'});buffer.add({id:2,kind:'ice',payload:'stale'});
 buffer.ready(buffer.version,async value=>{received.push(value);await new Promise(resolve=>release=resolve);});
 const oldDrain=buffer.chain;await Promise.resolve();buffer.reset();release();await oldDrain;
 assert.equal(received.length,1);
});
