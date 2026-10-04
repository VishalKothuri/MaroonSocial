import { build } from 'esbuild';
import { mkdir,copyFile,writeFile,readFile } from 'node:fs/promises';
const base=new URL('.',import.meta.url).pathname;
await mkdir(base+'../MaroonSocial/Resources',{recursive:true});
await build({entryPoints:[base+'src/renderer.js'],bundle:true,minify:true,format:'iife',target:'safari16',outfile:base+'../MaroonSocial/Resources/game-runtime.js',legalComments:'external'});
await build({entryPoints:[base+'src/engine.js'],bundle:true,minify:true,format:'esm',platform:'neutral',mainFields:['module','main'],target:'es2022',outfile:base+'../supabase/functions/games/engine.js',legalComments:'external'});
let notices='Maroon Social game engine licenses\n\n';
for(const name of ['matter-js','cannon-es','three','chess.js']){const license=await readFile(base+`node_modules/${name}/LICENSE`,'utf8');await writeFile(base+`licenses/${name}.txt`,license);notices+=`\n${name}\n${license}\n`;}
notices+='\nJBallin/beer-pong — adapted cup wall/bottom contact design\n'+await readFile(base+'licenses/JBallin-beer-pong.txt','utf8');
await writeFile(base+'../MaroonSocial/Resources/Game-Licenses.txt',notices);
await copyFile(base+'src/game-table.html',base+'../MaroonSocial/Resources/game-table.html');
