// npm run check:preferences
// Validate Preferences language packs independently of UI screenshots.
import { build } from 'esbuild'
const languages=['en','sr','de','es','it','fr','ru','pt']
const imports=languages.map(code=>"import "+code+" from './src/i18n/locales/"+code+".ts';").join('\n')
const entry=imports+"\nexport const locales={"+languages.join(',')+"};"
const {outputFiles}=await build({
  stdin:{contents:entry,resolveDir:process.cwd(),sourcefile:'preferences-check.ts',loader:'ts'},
  bundle:true,write:false,platform:'node',format:'esm',logLevel:'silent',
})
const {locales}=await import('data:text/javascript;base64,'+Buffer.from(outputFiles[0].text).toString('base64'))
const source=locales.en.preferencesCenter
const errors=[]
const variables=value=>[...String(value).matchAll(/{{\s*([^{}]+?)\s*}}/g)].map(x=>x[1]).sort().join('|')
function compare(ref,test,path,lang) {
 for(const [key,value] of Object.entries(ref)) {
   const p=path?path+'.'+key:key
   if(typeof value==='string') {
     if(typeof test?.[key]!=='string'||!test[key].trim())errors.push(lang+': missing '+p)
     else if(variables(test[key])!==variables(value))errors.push(lang+': placeholder mismatch '+p)
   }else if(value && typeof value==='object'){
     if(!test?.[key]||typeof test[key]!=='object')errors.push(lang+': missing section '+p)
     else compare(value,test[key],p,lang)
   }
 }
}
for(const lang of languages)compare(source,locales[lang].preferencesCenter,'preferencesCenter',lang)
if(errors.length){
 console.error(errors.join('\n'))
 process.exitCode=1
}else{
 console.log('Preferences locale coverage and interpolation passed for all eight languages.')
}
