// One icon per visible key, filled bottom-up to its percentage. Subscribes to
// window.qrState directly; no crosstalk involved.
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

    function icon(pct, gradientId, color) {
      return '<svg viewBox="0 0 24 24" width="64" height="64" aria-hidden="true">' +
        '<defs><linearGradient id="' + gradientId + '" x1="0" y1="1" x2="0" y2="0">' +
        '<stop offset="' + pct + '%" stop-color="' + esc(color) + '"/>' +
        '<stop offset="' + pct + '%" stop-color="#dde3e8"/>' +
        '</linearGradient></defs>' +
        '<path d="' + HOUSE + '" fill="url(#' + gradientId + ')" stroke="#555" stroke-width="0.6"/></svg>';
    }

    return {
      renderValue: function (x) {
        if (unsubscribe) unsubscribe();
        unsubscribe = window.qrState.subscribe(x.param, function (selected) {
          var shown = window.qrState.visible(x.param, selected) || x.keys;
          el.innerHTML = x.keys.map(function (key, i) {
            if (shown.indexOf(key) < 0) return '';
            var value = x.values[i];
            var pct = value === null ? 0 : Math.max(0, Math.min(100, value));
            var text = value === null ? '&ndash;' : esc(x.text[i]);
            return '<figure class="qr-icon" data-key="' + esc(key) + '">' +
              icon(pct, el.id + '-g' + i, window.qrState.color(x.param, key) || x.color) +
              '<figcaption>' + esc(x.labels[i]) + '<br><strong>' + text + '</strong></figcaption></figure>';
          }).join('');
        });
      },
      resize: function () {}
    };
  }
});
