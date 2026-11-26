import {build} from 'esbuild'
import {mkdir,copyFile} from 'node:fs/promises'
import {fileURLToPath} from 'node:url'
import path from 'node:path'
const root=fileURLToPath(new URL('../',import.meta.url))
const dir=path.join(root,'experiments/project-ace/react-dist')
await mkdir(dir,{recursive:true})
const result=await build({absWorkingDir:root,entryPoints:{react:'src/ace-pilot/main.tsx'},outdir:dir,bundle:true,format:'iife',jsx:'automatic',metafile:true,define:{'process.env.NODE_ENV':'"production"'},write:false})
// Fail closed if any existing app/auth/backend code enters the local bundle.
for(const name of Object.keys(result.metafile.inputs))if(!name.startsWith('node_modules/')&&!name.startsWith('src/ace-pilot/')&&name!=='src/styles/tournament-match-replay-score-v2.css')throw Error('Unexpected pilot dependency: '+name)
const {writeFile}=await import('node:fs/promises')
for(const file of result.outputFiles)await writeFile(file.path,file.contents)
await copyFile(path.join(root,'src/ace-pilot/index.html'),path.join(dir,'index.html'))
console.log('Built isolated Tennis Legacy React pilot; no production backend bundled.')
