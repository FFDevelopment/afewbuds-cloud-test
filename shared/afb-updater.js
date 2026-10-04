(function(){
  'use strict';

  const LOCAL_RELEASE = '0.7.9-beta.19-cloudtest.3';

  function overlay(show, title, detail){
    const root=document.getElementById('afb-prelaunch');
    const t=document.getElementById('afb-prelaunch-title');
    const d=document.getElementById('afb-prelaunch-detail');
    const p=document.getElementById('afb-prelaunch-progress');
    if(root) root.hidden=!show;
    if(t && title) t.textContent=title;
    if(d && detail) d.textContent=detail;
    if(p){ p.removeAttribute('data-indeterminate'); p.value=1; }
  }

  async function boot(){
    overlay(true,'Checking cloud test…','Looking for the newest standalone test build.');
    try{
      const response=await fetch('version.json?t='+Date.now(),{cache:'no-store',credentials:'same-origin'});
      if(response.ok){
        const live=await response.json();
        const release=String(live.release_id||'');
        if(release && release!==LOCAL_RELEASE){
          const url=new URL(location.href);
          if(url.searchParams.get('release')!==release){
            overlay(true,'Cloud test updated','Reloading '+release+'…');
            url.searchParams.set('release',release);
            url.searchParams.set('t',String(Date.now()));
            location.replace(url.toString());
            await new Promise(()=>{});
          } else {
            console.warn('Cloud-test release mismatch after reload; launching current files to avoid a reload loop.', {live:release, local:LOCAL_RELEASE});
          }
        }
      }
    }catch(e){
      console.warn('Cloud-test version check failed; launching current files.',e);
    }
    overlay(false);
  }

  window.AFB_UPDATER={
    boot,
    rollback:async()=>false,
    notifyGameStarting:function(){},
    markGameReady:function(){},
    markGameFailure:function(){},
    getState:function(){return{};},
    getLiveVersion:function(){return LOCAL_RELEASE;}
  };
})();
