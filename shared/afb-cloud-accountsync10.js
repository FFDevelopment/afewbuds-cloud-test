(function () {
  'use strict';
  // Inventory experiments read a cloud career once, but never upload gameplay.
  const PREFIX='afb_inventory_preview_v1:';
  let activeKey=null;
  const player=()=>window.AFB_API?.getPlayerSession?.() || null;
  const key=()=>PREFIX+(player()?.account_id || 'guest');
  const normalize=data=>Array.isArray(data)?normalize(data[0]):(data?.value && typeof data.value==='object'?data.value:data);
  const read=()=>{try{return JSON.parse(localStorage.getItem(key()) || 'null');}catch(_){return null;}};
  const summary=save=>save?`Preview copy · Day ${save.game_day || 1} · $${save.cash || 0}`:'New preview career';
  async function reconcileLatestSilently(){
    const previewKey=key();
    let save=read();
    const current=player();
    if(!save && current?.session_token){
      const result=normalize(await window.AFB_API.rpc('afb_get_save',{p_session_token:current.session_token}));
      save=result?.exists && result.save_json && typeof result.save_json==='object'?result.save_json:{};
      if(key()!==previewKey) throw new Error("Account changed while loading preview. Please launch again.");
      localStorage.setItem(previewKey,JSON.stringify(save));
    }
    // Always replace the shared runtime's boot file with this account's preview.
    activeKey=previewKey;
    window.AFB_CLOUD_BOOT_SAVE=JSON.stringify(save || {});
    return {action:'preview_copy',save:save || {}};
  }
  async function pushFromGame(payload){
    if(activeKey!==key())throw new Error('Preview account changed. Reload before saving.');
    const save=typeof payload==='string'?JSON.parse(payload):payload;
    if(!save || typeof save!=='object' || Array.isArray(save))throw new Error('Invalid preview save');
    localStorage.setItem(key(),JSON.stringify(save));
    window.AFB_CLOUD_STATUS={state:'local_only',preview:true,at:Date.now()};
    return {ok:true,preview:true,saved_unix:save.saved_unix};
  }
  window.AFB_CLOUD={reconcileLatestSilently,prepareBeforeLaunch:reconcileLatestSilently,
    startAutoSync(){},async syncLatest(){return {preview:true};},pushFromGame,
    async readLocalSave(){return read();},writeLocalSave:pushFromGame,summary};
})();
