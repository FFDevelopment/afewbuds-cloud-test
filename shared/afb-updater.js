(function(){
  'use strict';
  window.AFB_UPDATER = {
    boot: async function(){
      const overlay=document.getElementById('afb-prelaunch');
      if(overlay) overlay.hidden=true;
    },
    rollback: async function(){ return false; },
    notifyGameStarting: function(){},
    markGameReady: function(){},
    markGameFailure: function(){},
    getState: function(){ return {}; },
    getLiveVersion: function(){ return window.AFB_TEST_RELEASE || 'cloud-test'; }
  };
})();
