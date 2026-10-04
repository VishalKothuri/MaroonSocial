import {build} from 'esbuild';
import {cp,mkdir,readFile,writeFile,rm} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
process.chdir(path.dirname(new URL(import.meta.url).pathname));
await writeFile('upstream/src/utils/version.ts', "export const VERSION = 'maroon-preview-9cd48c5';\n");
await rm('dist',{recursive:true,force:true});await mkdir('dist/source',{recursive:true});
for(const name of ['assets','models','sounds','css'])await cp(`upstream/dist/${name}`,`dist/${name}`,{recursive:true});
for(const name of ['index.html','preview.css','source.html'])await cp(`web/${name}`,`dist/${name}`);
await cp('LICENSE','dist/LICENSE.txt');
await build({entryPoints:['web/entry.ts'],outfile:'dist/pool.js',bundle:true,minify:true,sourcemap:true,target:['safari16'],format:'esm',legalComments:'linked',plugins:[{name:'local-practice-only',setup(b){
 b.onResolve({filter:/^@tailuge\/messaging$/},()=>({path:path.resolve('web/no-network.ts')}));
 b.onResolve({filter:/\/scorereporter$/},()=>({path:path.resolve('web/local-scores.ts')}));
 b.onResolve({filter:/\/shorten$/},()=>({path:path.resolve('web/local-share.ts')}));
}}]});
let notices='Maroon Social pool preview: GPL-3.0. Upstream tailuge/billiards at 9cd48c5cc0986f86e5514d21f7668aa408d538ea.\n\n';
for(const name of ['three','interactjs','fflate','jsoncrush']){
 const pkg=JSON.parse(await readFile(`node_modules/${name}/package.json`));notices+=`\n--- ${name} ${pkg.version} (${pkg.license??'see package'}) ---\n`;
 for(const license of ['LICENSE','LICENSE.md','LICENSE.txt','license','LICENSE-MIT']){try{notices+=await readFile(`node_modules/${name}/${license}`,'utf8');notices+='\n';break}catch{}}
}
await writeFile('dist/THIRD-PARTY-LICENSES.txt',notices);
// Matching source lives beside the runnable build, including original full
// source, local adapters, dependency lock, licenses and reproducible scripts.
execFileSync('tar',['-czf','dist/source/maroon-pool-source.tar.gz','--exclude=upstream/.git','--exclude=upstream/node_modules','README.md','LICENSE','UPSTREAM.json','package.json','package-lock.json','build.mjs','make-page.mjs','jest.config.cjs','vercel.json','web','server','upstream']);
console.log('Built dist: static Vercel output, scoped multiplayer adapter + practice, corresponding source included.');
