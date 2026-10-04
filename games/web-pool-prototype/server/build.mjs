import {build} from 'esbuild';
await build({entryPoints:['server/engine.ts'],outfile:'server/engine.mjs',bundle:true,minify:true,platform:'neutral',format:'esm',target:'es2022',legalComments:'linked'});
