'use strict';
// AFewBuds cloud-test regression; all RPCs are in-memory mocks.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const fixture = JSON.parse(fs.readFileSync('tools/career_parity_v1/fixture.json', 'utf8'));
const clone = x => JSON.parse(JSON.stringify(x));
const backend = {save:clone(fixture),revision:8,play:null};
function client(){
  const storage = new Map();
  const account = {account_id:'fictional-qa-account',session_token:'fictional-session',username:'QA'};
  const api = {
    getPlayerSession:()=>account,
    rpc:async(method,p)=>{
      if(method === 'afb_begin_play'){
        backend.play=p.p_play_id;
        return {state:'active',revision:backend.revision,save_json:clone(backend.save),exists:true};
      }
      if(method === 'afb_save_career'){
        if(p.p_play_id!==backend.play) return {ok:false,reason:'session_replaced'};
        if(p.p_revision!==backend.revision) return {ok:false,reason:'save_conflict'};
        backend.save=clone(p.p_save_json);
        return {ok:true,revision:++backend.revision};
      }
      if(method === 'afb_play_heartbeat') return {state:p.p_play_id===backend.play?'active':'replaced'};
      if(method === 'afb_release_play') {backend.play=null;return {ok:true};}
      if(method === 'afb_leaderboard_report') return {ok:true};
      throw new Error('Unexpected RPC: '+method);
    }
  };
  const store = {
    getItem:key=>storage.get(key)||null,
    setItem:(key,val)=>storage.set(key,String(val)),
    removeItem:key=>storage.delete(key)
  };
  const window = {AFB_API:api};
  const context = {window,localStorage:store,Date,JSON,Error,Promise,console,crypto,
    setTimeout,clearTimeout,setInterval:()=>1,clearInterval:()=>{},
    structuredClone};
  vm.runInNewContext(fs.readFileSync(process.argv[2] || 'shared/afb-cloud-accountsync10.js','utf8'), context);
  return {cloud:window.AFB_CLOUD,window,storage};
}
(async()=>{
  const player=client();
  await player.cloud.prepareBeforeLaunch();
  const first=JSON.parse(player.window.AFB_CLOUD_BOOT_SAVE);
  assert.equal(first.location_state.furniture_v1.items.furniture_101.property,'house');
  assert.equal(first.location_state.furniture_v1.items.furniture_102.property,'backpack');
  assert.equal(first.production_worker_friend_name,'Malik');
  assert.equal(first.friend_staff_roles.Tyler,'dealer');
  assert.equal(first.location_state.staff_assignments.Tyler,'apartment');

  const edited=clone(first);
  edited.location_state.furniture_v1.items.furniture_101.property='backpack';
  delete edited.location_state.furniture_v1.items.furniture_101.position;
  delete edited.location_state.furniture_v1.items.furniture_101.yaw;
  edited.location_state.furniture_v1.items.furniture_101.locked=false;
  edited.location_state.staff_assignments.Tyler='house';
  edited.saved_unix+=7;
  await player.cloud.pushFromGame(edited);
  assert.equal(backend.save.location_state.furniture_v1.items.furniture_101.property,'backpack');
  assert.equal('position' in backend.save.location_state.furniture_v1.items.furniture_101,false);
  assert.equal(backend.save.location_state.furniture_v1.items.furniture_102.property,'backpack');
  assert.equal(backend.save.location_state.staff_assignments.Tyler,'house');
  assert.equal(backend.save.production_worker_friend_name,'Malik');
  assert.equal(backend.save.location_state.container_inventory.containers['apartment:storage']['product|Purple Dream'],16);
  assert.equal(backend.save.future_field.preserve_me,true);

  // New authoritative server content is loaded after a phone/desktop handoff.
  const phone=clone(backend.save);
  phone.location_state.staff_assignments.Tyler='apartment';
  phone.saved_unix+=9;
  backend.save=phone;
  backend.revision++;
  await player.cloud.prepareBeforeLaunch();
  const newer=JSON.parse(player.window.AFB_CLOUD_BOOT_SAVE);
  assert.equal(newer.location_state.staff_assignments.Tyler,'apartment');
  assert.equal(newer.location_state.furniture_v1.items.furniture_101.property,'backpack');
  assert.equal(newer.location_state.furniture_v1.items.furniture_102.property,'backpack');

  // A concurrent desktop update must win over a stale mobile revision.
  backend.save.location_state.staff_assignments.Tyler='house';
  backend.revision++;
  const stale=clone(newer);
  stale.location_state.staff_assignments.Tyler='apartment';
  await assert.rejects(()=>player.cloud.pushFromGame(stale),/save_conflict/);
  assert.equal(backend.save.location_state.staff_assignments.Tyler,'house');
  assert.ok(['replaced','save_conflict'].includes(player.window.AFB_CLOUD_EVENT));
  console.log('CAREER_PARITY_JS_RESULT: PASS (shared server, tents, workers, property storage, handoff, stale-save rejection)');
})().catch(e=>{console.error(e);process.exitCode=1;});
