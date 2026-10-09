import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {JSDOM} from 'jsdom';
// The full community guidelines text the app links to, and its link from the privacy page.
const guidelines=await readFile(new URL('../public/guidelines.html',import.meta.url),'utf8');
const privacy=await readFile(new URL('../public/privacy.html',import.meta.url),'utf8');
const migration=await readFile(new URL('../../supabase/migrations/20261007100000_community_guidelines.sql',import.meta.url),'utf8');

test('the page states the version the server requires at launch',()=>{
 const seeded=migration.match(/insert into social_private\.guidelines_settings\(id,required_version,enforced\)values\(true,(\d+),true\)/);
 assert.ok(seeded,'the migration seeds the required version');
 const dom=new JSDOM(guidelines);
 const version=dom.window.document.getElementById('guidelines-version');
 assert.equal(version.dataset.version,seeded[1]);
 assert.equal(version.textContent,'VERSION '+seeded[1]);
 assert.equal(dom.window.document.title,'Community guidelines · Maroon Social');
 dom.window.close();
});

test('the full text covers every rule, the crisis line and the support contact',()=>{
 const dom=new JSDOM(guidelines);
 const document=dom.window.document;
 const headings=[...document.querySelectorAll('main h2')].map(h=>h.textContent);
 assert.deepEqual(headings,['Be an Aggie','Leave other students out of it','No harassment, hate or threats','Keep sexual content in its place','No doxxing, spam, scams or illegal sales','Anonymity is not immunity','Report and block','If you’re struggling','Contact']);
 const text=document.querySelector('main').textContent;
 for(const phrase of['name, initial or picture other students','encouraging anyone to hurt themselves','outside the 18+ NSFW community','Never anything involving minors','sell or promote anything illegal','law-enforcement requests','Report','Block','988'])assert.ok(text.includes(phrase),phrase);
 assert.ok(document.querySelector('a[href="tel:988"]'),'988 is a tappable link');
 const contact=document.getElementById('support-contact');
 assert.equal(contact.getAttribute('href'),'mailto:support@maroonsocial.chat');
 assert.equal(contact.textContent,'support@maroonsocial.chat');
 dom.window.close();
});

test('the page uses the shared stylesheet and nothing the CSP blocks',()=>{
 const dom=new JSDOM(guidelines);
 const document=dom.window.document;
 assert.equal(document.querySelector('link[rel="stylesheet"]').getAttribute('href'),'/style.css');
 assert.equal(document.querySelectorAll('script,style,[style]').length,0);
 assert.equal(document.querySelector('.site-header .wordmark').getAttribute('href'),'/');
 assert.ok(document.querySelector('main a[href="/privacy.html"]'),'links back to privacy');
 dom.window.close();
});

test('the privacy page links to the guidelines',()=>{
 const dom=new JSDOM(privacy);
 const link=dom.window.document.getElementById('guidelines-link');
 assert.ok(link,'guidelines link present');
 assert.equal(link.getAttribute('href'),'/guidelines.html');
 assert.ok(dom.window.document.querySelector('a[href="mailto:support@maroonsocial.chat"]'),'support contact present');
 dom.window.close();
});
