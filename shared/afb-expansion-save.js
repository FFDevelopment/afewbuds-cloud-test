(function(){
 'use strict';
 const api=window.AFB_API, original=api.rpc.bind(api), prefix='afb_expansion_career_v1:';
 const clone=x=>JSON.parse(JSON.stringify(x));
 const normalize=x=>Array.isArray(x)?normalize(x[0]):x?.value&&typeof x.value==='object'?x.value:x;
 let account=null, slot=null, stopped=false;
 const session=()=>api.getPlayerSession?.()||null;
 const same=()=>slot===prefix+(session()?.account_id||'guest');
 const blocked=new Set(['afb_set_save','afb_save_career','afb_begin_play','afb_play_heartbeat','afb_release_play','afb_leaderboard_report']);
 api.rpc=async(name,args)=>{if(blocked.has(name))throw Error('Test careers cannot modify live progression or sessions.');return original(name,args);};
 function event(state){window.AFB_CLOUD_EVENT=state;window.AFB_CLOUD_STATUS={state,at:Date.now()};}
 function read(){const raw=localStorage.getItem(slot);return raw?JSON.parse(raw):null;}
 async function prepare(){
  account=session();slot=prefix+(account?.account_id||'guest');stopped=false;
  let save=read();
  if(save===null){
   save={};
   if(account?.session_token){
    const r=normalize(await api.rpc('afb_get_save',{p_session_token:account.session_token}));
    if(r?.error)throw Error(r.error);
    if(!r || typeof r!=='object')throw Error('Could not load cloud career.');
    if(!same())throw Error('Account changed. Sign in again.');
    save=r.exists?r.save_json||{}:{};
   }
   if(Number(save.save_schema||0)>2)throw Error('This career needs a newer game version.');
   localStorage.setItem(slot,JSON.stringify(save));
  }
  window.AFB_CLOUD_BOOT_SAVE=JSON.stringify(save);event('active');return {action:'local',save:clone(save)};
 }
 async function push(payload){
  if(stopped||!same())throw Error('session_replaced');
  const save=typeof payload==='string'?JSON.parse(payload):clone(payload);
  if(!save||typeof save!=='object'||Array.isArray(save))throw Error('save_invalid');
  localStorage.setItem(slot,JSON.stringify(save));event('active');return {ok:true,local:true};
 }
 window.AFB_CLOUD={prepareBeforeLaunch:prepare,reconcileLatestSilently:prepare,pushFromGame:push,writeLocalSave:push,readLocalSave:async()=>read(),
  startAutoSync:()=>{},syncLatest:async()=>({ok:true,local:true}),heartbeat:async()=>{},finishHandoff:async()=>{},
  releasePlay:async()=>{stopped=true;return {ok:true};},summary:s=>s?`Day ${s.game_day||1}`:'New career'};
})();
