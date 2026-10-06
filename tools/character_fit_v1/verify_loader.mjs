// Exercise the shipped browser loader with local, hash-checked source files.
import { readFile } from 'node:fs/promises';
import { resolve, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { webcrypto } from 'node:crypto';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const requests=[];
const sandbox={window:{},crypto:webcrypto,atob:s=>Buffer.from(s,'base64').toString('binary'),Uint8Array,
  fetch:async url=>{
    const path=resolve(root,url.split('?')[0]);
    assert(!relative(root,path).startsWith('..'));
    requests.push(url);
    const bytes=await readFile(path);
    return {ok:true,json:async()=>JSON.parse(bytes),arrayBuffer:async()=>Uint8Array.from(bytes).buffer};
  }
};
vm.runInNewContext(await readFile(resolve(root,'shared/afb-runtime-character-fit-v1.js'),'utf8'),sandbox);
const engine={preloadFile:async(file,path)=>({file,path})};
sandbox.window.AFB_RUNTIME_CHARACTER_FIT_V1.install(engine);
const untouched=await engine.preloadFile('index.wasm','index.wasm');
assert.equal(untouched.file,'index.wasm');
const loaded=await engine.preloadFile('index-character-fit-v1.pck','index-character-fit-v1.pck');
const recipe=JSON.parse(await readFile(resolve(root,'runtime/character-fit-v1.patch.json')));
const hash=Buffer.from(await webcrypto.subtle.digest('SHA-256',loaded.file)).toString('hex');
assert.equal(hash,recipe.target_sha256);assert.equal(loaded.file.byteLength,recipe.target_size);
assert.equal(loaded.path,'index-character-fit-v1.pck');
console.log(JSON.stringify({passed:true,bytes:loaded.file.byteLength,sha256:hash,fetches:requests.length,unchanged_wasm_pass_through:true},null,2));
