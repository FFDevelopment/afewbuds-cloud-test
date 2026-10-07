/* Build the verified mobile-3d-v1 pack from unchanged .63 assets plus this release's small delta. */
(function () {
  'use strict';
  let packPromise = null;
  const hex = bytes => Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, '0')).join('');
  async function sha256(bytes) { return hex(await crypto.subtle.digest('SHA-256', bytes)); }
  async function checkedFetch(url) {
    const response = await fetch(url);
    if (!response.ok) throw new Error('Game download failed (' + response.status + '). Please reload.');
    return response;
  }
  async function buildPack() {
    const recipe = await (await checkedFetch('runtime/mobile-3d-v1.patch.json?v=3')).json();
    if (recipe.format !== 'afb-pack-delta-1') throw new Error('Game update format is invalid.');
    const base = new Uint8Array(await (await checkedFetch(recipe.base_url)).arrayBuffer());
    if (base.byteLength !== recipe.base_size || await sha256(base) !== recipe.base_sha256)
      throw new Error('The game assets do not match this update. Please refresh the page.');
    const pack = new Uint8Array(recipe.target_size);
    let offset = 0;
    for (const segment of recipe.segments) {
      if (segment[0] === 'copy') {
        const from = segment[1], length = segment[2];
        if (!Number.isInteger(from) || !Number.isInteger(length) || from < 0 || length < 0 || from + length > base.byteLength || offset + length > pack.byteLength)
          throw new Error('Game update contains an invalid asset range.');
        pack.set(base.subarray(from, from + length), offset);
        offset += length;
      } else if (segment[0] === 'zero') {
        const length = segment[1];
        if (!Number.isInteger(length) || length < 0 || offset + length > pack.byteLength) throw new Error('Invalid game update padding.');
        offset += length;
      } else if (segment[0] === 'asset') {
        const asset = new Uint8Array(await (await checkedFetch(segment[1])).arrayBuffer());
        if (asset.byteLength !== segment[2] || offset + asset.byteLength > pack.byteLength || await sha256(asset) !== segment[3]) throw new Error('Character asset verification failed.');
        pack.set(asset, offset); offset += asset.byteLength;
      } else if (segment[0] === 'data') {
        const decoded = atob(segment[1]);
        if (offset + decoded.length > pack.byteLength) throw new Error('Invalid game update length.');
        for (let i = 0; i < decoded.length; i++) pack[offset + i] = decoded.charCodeAt(i);
        offset += decoded.length;
      } else throw new Error('Unknown game update segment.');
    }
    if (offset !== pack.byteLength || await sha256(pack) !== recipe.target_sha256)
      throw new Error('Game update verification failed. Please reload.');
    return pack;
  }
  window.AFB_RUNTIME_MOBILE_3D_V1 = {
    install(engine) {
      const preload = engine.preloadFile.bind(engine);
      engine.preloadFile = function (file, path) {
        if (file !== 'index-mobile-3d-v1.pck') return preload(file, path);
        if (!packPromise) packPromise = buildPack().catch(error => { packPromise = null; throw error; });
        return packPromise.then(pack => preload(pack.buffer, path)).finally(() => { packPromise = null; });
      };
    }
  };
}());
