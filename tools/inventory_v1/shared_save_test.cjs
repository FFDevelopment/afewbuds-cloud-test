const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const clone=x=>JSON.parse(JSON.stringify(x));
const backend={save:{cash:500,save_schema:2,location_state:{container_inventory:{backpack:{'seed|Purple Dream':5}}}},revision:0,active:null,pending:null,fail:false,reject:false};
function client(accountId='a',storage=new Map()){
 let session={account_id:accountId,session_token:'fixture-'+accountId};
 const rpc=async(name,p)=>{
  if(backend.fail)throw Error('offline');
  if(name==='afb_begin_play'){
   if(backend.active && backend.active!==p.p_play_id){backend.pending=p.p_play_id;return {state:'waiting'};}
   backend.active=p.p_play_id;backend.pending=null;return {state:'active',revision:backend.revision,save_json:clone(backend.save)};
  }
  if(name==='afb_play_heartbeat')return {state:backend.active!==p.p_play_id?'replaced':backend.pending?'handoff':'active'};
  if(name==='afb_save_career'){
   if(backend.reject)return {ok:false,reason:'save_conflict'};
   if(p.p_play_id!==backend.active)return {ok:false,reason:'session_replaced'};
   if(p.p_revision!==backend.revision)return {ok:false,reason:'save_conflict'};
   backend.save=clone(p.p_save_json);return {ok:true,revision:++backend.revision};
  }
  if(name==='afb_release_play'){if(p.p_play_id!==backend.active)return {ok:false};backend.active=null;return {ok:true};}
  if(name==='afb_leaderboard_report')return {ok:true};
  throw Error('unexpected RPC '+name);
 };
 const context={window:{AFB_API:{getPlayerSession:()=>session,clearPlayerSession:()=>session=null,rpc}},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,String(v))},crypto,Date,JSON,Error,setTimeout,clearTimeout,setInterval:()=>1,clearInterval:()=>{}};
 vm.runInNewContext(fs.readFileSync('shared/afb-cloud-accountsync10.js','utf8'),context);
 return {cloud:context.window.AFB_CLOUD,window:context.window,storage,setSession:s=>session=s};
}
(async()=>{
 const storage=new Map([['afb_inventory_preview_v1:a',JSON.stringify({cash:9999})]]);
 const phone=client('a',storage);await phone.cloud.prepareBeforeLaunch();assert.equal(JSON.parse(phone.window.AFB_CLOUD_BOOT_SAVE).cash,500);assert.equal(JSON.parse(storage.get('afb_inventory_preview_v1:a')).cash,9999);
 const save=clone(backend.save);save.cash=475;save.location_state.container_inventory.backpack['seed|Purple Dream']=4;
 await phone.cloud.pushFromGame(save);assert.deepEqual(backend.save,save);
 const next=client();const launch=next.cloud.prepareBeforeLaunch();await new Promise(r=>setTimeout(r,10));await phone.cloud.heartbeat();assert.equal(phone.window.AFB_CLOUD_EVENT,'handoff');
 save.cash=450;await phone.cloud.pushFromGame(save);await phone.cloud.finishHandoff();await launch;
 assert.equal(phone.window.AFB_CLOUD_EVENT,'replaced');assert.deepEqual(JSON.parse(next.window.AFB_CLOUD_BOOT_SAVE),save);
 await assert.rejects(()=>phone.cloud.pushFromGame({cash:1000}),/replaced/);
 backend.fail=true;await assert.rejects(()=>next.cloud.pushFromGame({...save,cash:425}),/offline/);assert.equal(backend.save.cash,450);
 assert.equal(JSON.parse(next.storage.get('afb_shared_career_v1:a')).save.cash,425);
 backend.fail=false;await next.cloud.syncLatest();assert.equal(backend.save.cash,425);
 backend.reject=true;await assert.rejects(()=>next.cloud.pushFromGame({...save,cash:1}),/save_conflict/);assert.equal(backend.save.cash,425);assert.equal(next.window.AFB_CLOUD_EVENT,'replaced');backend.reject=false;
 backend.active=null;const guest=client();guest.setSession(null);await guest.cloud.prepareBeforeLaunch();await guest.cloud.pushFromGame({cash:12});assert.equal(backend.save.cash,425);
 const switched=client();await switched.cloud.prepareBeforeLaunch();switched.setSession({account_id:'b',session_token:'fixture-b'});await assert.rejects(()=>switched.cloud.pushFromGame({cash:1}),/replaced/);
 console.log('SHARED_SAVE_TEST_RESULT: PASS (cloud load, preview backup, exact inventory, handoff, stale device, offline retry, rejected save, guests, account change)');
})().catch(e=>{console.error(e);process.exitCode=1});
