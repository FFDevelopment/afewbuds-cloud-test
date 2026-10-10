'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const ROOT='.';
const publicPhone=fs.readFileSync('shared/afb-cloud.js','utf8');
const recovery=fs.readFileSync('shared/afb-local-recovery.js','utf8');
const original=fs.readFileSync('shared/afb-expansion-save.js','utf8');
const html=fs.readFileSync('index.html','utf8');
const clone=x=>JSON.parse(JSON.stringify(x));
assert(!html.includes('<script src="shared/afb-expansion-save.js'));
assert(html.indexOf('shared/afb-local-recovery.js')<html.indexOf('shared/afb-cloud.js'));
assert(/afb_begin_play/.test(publicPhone)&&/afb_save_career/.test(publicPhone));
function fixture(){
 return {save_schema:2,saved_unix:1800000100,game_day:30,cash:2600,
  packing_employee_hired:true,production_worker_friend_name:'Malik',
  friend_staff_roles:{Malik:'production',Tyler:'dealer'},
  location_state:{staff_assignments:{Malik:'house',Tyler:'apartment'},
    furniture_v1:{schema:2,items:{'tent_one':{sku:'tent_2',property:'apartment',position:[0,0,-8],locked:true},
      'tent_packed':{sku:'tent_1',property:'backpack',locked:false}}},
    container_inventory:{containers:{'apartment:storage':{'product|Purple Dream':22}}}}};
}
function env(savedLocal,remoteSave,backupFailure=false){
 const account={account_id:'fictitious-A',session_token:'fictional',username:'QA'};
 const storage=new Map([['afb_expansion_career_v1:'+account.account_id,JSON.stringify(savedLocal)]]);
 let remote=clone(remoteSave),rev=14,play=null,uploaded=0;
 class Element{
  constructor(tag){this.tagName=tag;this.children=[];this.style={};this.textContent='';this.onclick=null;this.id='';}
  appendChild(child){child.parent=this;this.children.push(child);return child;}
  remove(){if(this.parent)this.parent.children=this.parent.children.filter(x=>x!==this);}
  find(tag){return this.tagName===tag?[this]:this.children.flatMap(c=>c.find(tag));}
 }
 const document={body:new Element('body'),createElement:tag=>new Element(tag)};
 const api={getPlayerSession:()=>account,rpc:async(method,p)=>{
  if(method==='afb_begin_play'){play=p.p_play_id;return{state:'active',exists:true,revision:rev,save_json:clone(remote)};}
  if(method==='afb_play_heartbeat')return{state:p.p_play_id===play?'active':'replaced'};
  if(method==='afb_save_career'){
   if(p.p_play_id!==play)return{ok:false,reason:'session_replaced'};
   if(p.p_revision!==rev)return{ok:false,reason:'save_conflict'};
   uploaded++;remote=clone(p.p_save_json);return{ok:true,revision:++rev};
  }
  if(method==='afb_release_play')return{ok:true};
  if(method==='afb_leaderboard_report')return{ok:true};
  throw Error('unexpected RPC '+method);
 }};
 const localStorage={
  getItem:k=>storage.get(k)||null,
  setItem:(k,v)=>{if(backupFailure&&k.startsWith('afb_cloudtest_local_recovery_v1:'))throw Error('quota');storage.set(k,String(v));},
  removeItem:k=>storage.delete(k)
 };
 const window={AFB_API:api,confirm:()=>true};
 const context={window,document,localStorage,crypto,JSON,Promise,console,Date,Error,
   setTimeout,clearTimeout,setInterval:()=>1,clearInterval:()=>{}};
 vm.runInNewContext(recovery,context);
 vm.runInNewContext(publicPhone,context);
 const buttons=()=>document.body.find('button');
 return{window,document,buttons,storage,account,get remote(){return remote;},get uploaded(){return uploaded;},get rev(){return rev;}};
}
async function tick(){for(let i=0;i<15;i++)await Promise.resolve();}
async function testRestore(){
 const mobile=fixture(),server=fixture();
 mobile.location_state.furniture_v1.items.tent_one.property='house';
 mobile.location_state.furniture_v1.items.tent_one.position=[41.8,0,-12];
 mobile.location_state.staff_assignments.Tyler='house';
 mobile.saved_unix+=300;
 const x=env(mobile,server),start=x.window.AFB_CLOUD.prepareBeforeLaunch();
 await tick();
 assert.equal(x.uploaded,0,'never auto-upload an unreconciled local career');
 const buttons=x.buttons();
 assert.equal(buttons.length,3);
 assert(buttons[0].textContent.includes('THIS BROWSER'));
 assert(x.storage.has('afb_cloudtest_local_recovery_v1:'+x.account.account_id+':mobile'));
 assert(x.storage.has('afb_cloudtest_local_recovery_v1:'+x.account.account_id+':server'));
 assert.deepEqual(JSON.parse(x.storage.get('afb_expansion_career_v1:'+x.account.account_id)),mobile);
 buttons[0].onclick();
 await start;
 assert.equal(x.uploaded,1,'only confirmed local restore writes the server');
 assert.equal(x.remote.location_state.furniture_v1.items.tent_one.property,'house');
 assert.equal(x.remote.location_state.staff_assignments.Tyler,'house');
 assert.equal(x.remote.production_worker_friend_name,'Malik');
 assert.equal(x.remote.location_state.furniture_v1.items.tent_packed.property,'backpack');
 assert.equal(x.remote.location_state.container_inventory.containers['apartment:storage']['product|Purple Dream'],22);
 assert.equal(x.window.AFB_CLOUD_BOOT_SAVE.length>0,true);
 assert(x.storage.has('afb_cloudtest_recovery_completed_v1:'+x.account.account_id));
 await x.window.AFB_CLOUD.releasePlay();
 // The original local-only copy is preserved for future rollback.
 assert.deepEqual(JSON.parse(x.storage.get('afb_expansion_career_v1:'+x.account.account_id)),mobile);
}
async function testServer(){
 const local=fixture(),server=fixture();
 local.location_state.staff_assignments.Tyler='house';
 const x=env(local,server),wait=x.window.AFB_CLOUD.prepareBeforeLaunch();await tick();
 x.buttons()[1].onclick();await wait;
 assert.equal(x.uploaded,0);
 assert.equal(JSON.parse(x.window.AFB_CLOUD_BOOT_SAVE).location_state.staff_assignments.Tyler,'apartment');
 assert.equal(JSON.parse(x.storage.get('afb_expansion_career_v1:'+x.account.account_id)).location_state.staff_assignments.Tyler,'house');
}
async function testCancel(){
 const local=fixture(),server=fixture();
 server.saved_unix-=300;
 const x=env(local,server),wait=x.window.AFB_CLOUD.prepareBeforeLaunch();await tick();
 x.buttons()[2].onclick();
 await assert.rejects(wait,/canceled/);
 assert.equal(x.uploaded,0);
 assert.equal(x.storage.has('afb_cloudtest_recovery_completed_v1:'+x.account.account_id),false);
 assert.equal(x.storage.has('afb_public_career_v1:'+x.account.account_id),false);
}
async function testQuota(){
 const local=fixture(),server=fixture();
 const x=env(local,server,true);
 await assert.rejects(()=>x.window.AFB_CLOUD.prepareBeforeLaunch(),/back up/);
 assert.equal(x.uploaded,0);
}
(async()=>{
 await testRestore();await testServer();await testCancel();await testQuota();
 console.log('CLOUDTEST_RECOVERY_RESULT: PASS (explicit choice, both backups, no silent write, recovery, abort, quota protection)');
})().catch(e=>{console.error(e);process.exitCode=1;});
