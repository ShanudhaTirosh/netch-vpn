/* ==========================================================================
   Netch VPN / NovaNetchX — runtime rebrand for the stock 3x-ui SPA.
   Injected via Nginx sub_filter (same as the favicon/theme), so the official
   prebuilt panel shows "SX-UI" instead of "3X-UI" without a source rebuild.
   Only TEXT NODES are touched — link hrefs (e.g. github.com/MHSanaei/3x-ui)
   are left intact. A MutationObserver re-applies after React re-renders.
   ========================================================================== */
(function () {
  "use strict";
  var FROM = "SX-UI";
  // Match the brand token in its common displayed forms; case-insensitive.
  var RE = /3\s*[xX]\s*-?\s*UI/g;

  function rebrandTextNodes(root) {
    if (!root) return;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var node, batch = [];
    while ((node = walker.nextNode())) batch.push(node);
    for (var i = 0; i < batch.length; i++) {
      var t = batch[i];
      var v = t.nodeValue;
      if (v && RE.test(v)) {
        RE.lastIndex = 0;
        t.nodeValue = v.replace(RE, FROM);
      }
      RE.lastIndex = 0;
    }
  }

  function rebrandTitle() {
    if (RE.test(document.title)) {
      RE.lastIndex = 0;
      document.title = document.title.replace(RE, FROM);
    }
    RE.lastIndex = 0;
  }

  function run() {
    try { rebrandTextNodes(document.body); rebrandTitle(); } catch (e) { /* ignore */ }
  }

  function start() {
    run();
    try {
      var mo = new MutationObserver(function () { run(); });
      mo.observe(document.body, { childList: true, subtree: true, characterData: true });
    } catch (e) { /* ignore */ }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
