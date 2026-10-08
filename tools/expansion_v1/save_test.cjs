const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const live={cash:1234,save_schema:2}, storage=new Map(),calls=[];let session={account_id:'one',session_token:'fixture'};
const context={window:{AFB_API:{getPlayerSession:()=>session,rpc:async(name)=>{calls.push(name);assert.equal(name,'afb_get_save');return {exists:true,save_json:live};}}},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},Date,JSON,Error,Set};
vm.runInNewContext(fs.readFileSync('shared/afb-expansion-save.js','utf8'),context);
(async()=>{
 const c=context.window.AFB_CLOUD;await c.prepareBeforeLaunch();assert.equal(JSON.parse(context.window.AFB_CLOUD_BOOT_SAVE).cash,1234);
 await c.pushFromGame({cash:777,save_schema:2});assert.equal(live.cash,1234);await c.prepareBeforeLaunch();assert.equal(JSON.parse(context.window.AFB_CLOUD_BOOT_SAVE).cash,777);assert.equal(calls.length,1);
 for(const method of ['afb_set_save','afb_save_career','afb_begin_play','afb_play_heartbeat','afb_release_play','afb_leaderboard_report'])await assert.rejects(()=>context.window.AFB_API.rpc(method,{}),/cannot modify/);
 await c.heartbeat();await c.syncLatest();assert.equal(calls.length,1);
 session={account_id:'two',session_token:'fixture2'};await assert.rejects(()=>c.pushFromGame({cash:1}),/session_replaced/);await c.prepareBeforeLaunch();assert.equal(JSON.parse(context.window.AFB_CLOUD_BOOT_SAVE).cash,1234);
 session=null;await c.prepareBeforeLaunch();await c.pushFromGame({cash:50});assert.equal(JSON.parse(storage.get('afb_expansion_career_v1:one')).cash,777);assert.equal(calls.length,2);
 console.log('EXPANSION_SAVE_TEST_RESULT: PASS');
})().catch(e=>{console.error(e);process.exit(1)});
