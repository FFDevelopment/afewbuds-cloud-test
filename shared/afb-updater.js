(function(){
  'use strict';
  window.AFB_UPDATER = {
    boot: async function(){
      var overlay = document.getElementById('afb-prelaunch');
      if (overlay) overlay.hidden = true;
    },
    rollback: async function(){ return false; },
    notifyGameStarting: function(){},
    markGameReady: function(){},
    markGameFailure: function(){},
    getState: function(){ return {}; },
    getLiveVersion: function(){ return null; }
  };
})();
