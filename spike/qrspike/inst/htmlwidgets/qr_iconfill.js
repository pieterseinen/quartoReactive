// Custom widget: one icon per selected key, filled bottom-up to its percentage.
// Subscribes to window.qrState directly; no crosstalk involved.
HTMLWidgets.widget({
  name: 'qr_iconfill',
  type: 'output',

  factory: function (el) {
    var HOUSE = 'M12 2 L1 11 H4 V22 H20 V11 H23 Z';
    var unsubscribe = null;

    function esc(s) {
      return String(s).replace(/[&<>"]/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
      });
    }

    function icon(pct, gradientId) {
      return '<svg viewBox="0 0 24 24" width="64" height="64">' +
        '<defs><linearGradient id="' + gradientId + '" x1="0" y1="1" x2="0" y2="0">' +
        '<stop offset="' + pct + '%" stop-color="#2a7ab0"/>' +
        '<stop offset="' + pct + '%" stop-color="#dde3e8"/>' +
        '</linearGradient></defs>' +
        '<path d="' + HOUSE + '" fill="url(#' + gradientId + ')" stroke="#555" stroke-width="0.6"/></svg>';
    }

    return {
      renderValue: function (x) {
        if (unsubscribe) unsubscribe();
        unsubscribe = window.qrState.subscribe(x.param, function (selected) {
          // An empty selection shows everything, like the crosstalk bridge.
          var show = selected.length ? selected.concat(window.qrState.always(x.param)) : x.keys;
          el.innerHTML = x.keys.map(function (key, i) {
            if (show.indexOf(key) < 0) return '';
            var pct = Math.round(x.values[i]);
            return '<figure class="qr-icon" data-key="' + esc(key) + '" ' +
              'style="display:inline-block;text-align:center;margin:0 1em">' +
              icon(pct, el.id + '-g' + i) +
              '<figcaption>' + esc(x.labels[i]) + '<br><strong>' + pct + '%</strong></figcaption></figure>';
          }).join('');
        });
      },
      resize: function () {}
    };
  }
});
