import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
// 8 Ball is hidden, not removed: the link stays in the page with the hidden attribute.
const html=await readFile(new URL('../public/index.html',import.meta.url),'utf8');
test('the 8 Ball pool link stays in the page but is hidden',()=>{
 const dom=new JSDOM(html);
 const link=dom.window.document.getElementById('pool-link');
 assert.ok(link,'pool link is kept');
 assert.equal(link.hidden,true);
 assert.equal(link.getAttribute('href'),'https://maroon-social-games.vercel.app');
 dom.window.close();
});
