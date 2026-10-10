/* Safe recovery of Cloud Test's former browser-only career.
 * The current public phone's protected AFB_CLOUD client performs all server writes.
 * No old save is deleted, silently merged, or automatically uploaded.
 */
(function () {
 'use strict';
 const PREFIX = 'afb_expansion_career_v1:';
 const BACKUP = 'afb_cloudtest_local_recovery_v1:';
 const DONE = 'afb_cloudtest_recovery_completed_v1:';
 const clone = value => JSON.parse(JSON.stringify(value));
 const unix = save => Number(save?.saved_unix || 0);
 const isCareer = data => data && typeof data === 'object' && !Array.isArray(data);
 const propertyOf = (save,name) => String(save?.location_state?.staff_assignments?.[name] || 'apartment');

 function writeBackup(key, data) {
   try {
     // Never replace a prior snapshot with an older candidate.
     const previous = JSON.parse(localStorage.getItem(key) || 'null');
     if (!previous || unix(data) > unix(previous)) localStorage.setItem(key, JSON.stringify(data));
     return true;
   } catch (error) {
     console.error('AFewBuds career backup failed', error);
     return false;
   }
 }

 async function prepare(account) {
   const owner = account?.account_id ? String(account.account_id) : 'guest';
   const key = PREFIX + owner;
   const raw = localStorage.getItem(key);
   if (!raw) return null;
   let save;
   try { save = JSON.parse(raw); }
   catch (error) { throw Error('Your browser has a Cloud Test career that could not be decoded. It has not been changed.'); }
   if (!isCareer(save)) throw Error('Your saved Cloud Test career is invalid. It has not been changed.');
   if (Number(save.save_schema || 0) > 2) throw Error('This career requires a newer game; the browser copy is untouched.');
   if (!writeBackup(BACKUP + owner + ':mobile', save)) {
     throw Error('Could not back up the local mobile career. No server changes were made. Free browser storage and try again.');
   }
   return {save:clone(save),owner:account ? owner : '',
     matches:!!account, doneKey:DONE + owner, done:!!localStorage.getItem(DONE + owner)};
 }

 function countTents(save) {
   const items=save?.location_state?.furniture_v1?.items || {};
   const tents=Object.values(items).filter(e=>isCareer(e) && (String(e.sku||'').startsWith('tent_')||e.sku==='grow_tent'));
   return {placed:tents.filter(x=>x.property==='apartment'||x.property==='house').length,
           packed:tents.filter(x=>x.property==='backpack').length};
 }
 function describe(save) {
   const count=countTents(save);
   const roles=save?.friend_staff_roles||{};
   const list=Object.keys(roles).filter(n=>roles[n]).slice(0,5)
     .map(n=>n+' ('+roles[n]+', '+propertyOf(save,n)+')').join(', ');
   const time=unix(save)>0?new Date(unix(save)*1000).toLocaleString():'unknown';
   return 'Day '+(save?.game_day||1)+' · $'+(save?.cash||0)+' · placed tents: '+count.placed+
     ' · packed tents: '+count.packed+' · saved: '+time+' · staff: '+(list||'none recorded');
 }

 function choose(snapshot,cloud) {
   if (!snapshot || !snapshot.matches || snapshot.done) return Promise.resolve(null);
   if (JSON.stringify(snapshot.save) === JSON.stringify(cloud)) return Promise.resolve(null);
   // Backup both candidates before the player chooses. The old local original
   // remains in afb_expansion_career_v1 regardless of the decision.
   if (!writeBackup(BACKUP+snapshot.owner+':mobile',snapshot.save)
       || !writeBackup(BACKUP+snapshot.owner+':server',isCareer(cloud)?cloud:{})) {
     return Promise.reject(Error('Cannot create safe save backups; nothing was uploaded.'));
   }
   return new Promise((resolve,reject) => {
     const overlay=document.createElement('div');
     overlay.id='afb-cloudtest-recover-choice';
     overlay.style.cssText='position:fixed;inset:0;z-index:20000;background:#07150fee;display:grid;place-items:center;overflow:auto;padding:16px;font:16px/1.5 system-ui,sans-serif;color:#eaf4e6';
     const card=document.createElement('div');
     card.style.cssText='width:min(620px,100%);background:#14251b;border:1px solid #80ac74;border-radius:16px;padding:24px;box-shadow:0 12px 60px #0008';
     overlay.appendChild(card);
     const add=(tag,text)=>{const e=document.createElement(tag);e.textContent=text;card.appendChild(e);return e;};
     add('h2','Recover your AFewBuds career');
     add('p','The previous Cloud Test saved only to this browser. The phone and Windows now use one protected server career. The two copies differ. Neither has been overwritten.');
     const row=(heading,save)=>{
       const div=add('div',heading+'\n'+describe(save));
       div.style.cssText='white-space:pre-line;margin:12px 0;padding:12px;border:1px solid #486a4a;border-radius:8px;background:#1d3023;font-size:14px';
     };
     row('THIS BROWSER (former Cloud Test local save)',snapshot.save);
     row('SERVER (used by the Windows and phone tester versions)',cloud);
     add('p','Both snapshots are backed up in this browser. Choosing the local career replaces the server career only after you confirm; choosing the server keeps the original browser copy untouched.');
     const button=(label,onClick)=>{
       const e=add('button',label);
       e.type='button';e.style.cssText='display:block;width:100%;min-height:54px;padding:12px;margin:10px 0;border:1px solid #83ae75;border-radius:10px;background:#326c30;color:#fff;font:inherit;cursor:pointer;text-align:left';
       e.onclick=onClick;return e;
     };
     function close(){overlay.remove();}
     button('Use THIS BROWSER career — restore my tent and worker changes to the server',()=>{
       const ok=window.confirm('Restore this browser’s AFewBuds career to your server account? The current server snapshot is backed up in this browser. This is the only action that replaces the server career.');
       if(!ok)return;
       close();resolve(clone(snapshot.save));
     });
     button('Use SERVER career — keep my Windows/phone tester progress',()=>{close();resolve(null);});
     button('CANCEL — do not load or change either career',()=>{
       close();reject(Error('Save selection canceled. Neither career was changed.'));
     });
     document.body.appendChild(overlay);
   });
 }
 window.AFB_LEGACY={prepare,choose};
})();
