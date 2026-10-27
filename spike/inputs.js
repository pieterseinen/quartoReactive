// Shared spike input layer: turns a control's value into a list of matching row
// keys and hands it to window.qrSpikeSink(group, variable), which each prototype
// defines differently.
(function () {
  'use strict';

  function boot(container) {
    var group = container.dataset.group;
    var data = JSON.parse(document.getElementById(group + '-filterdata').textContent);

    container.querySelectorAll('[data-qr-var]').forEach(function (el) {
      var variable = el.dataset.qrVar;
      var sink = window.qrSpikeSink(group, variable);
      var col = data.cols[variable];

      function apply(value) {
        if (value === '__all__') { sink.clear(); return; }
        var keys = [];
        for (var i = 0; i < col.length; i++) if (col[i] === value) keys.push(data.keys[i]);
        sink.set(keys);
      }

      el.addEventListener('change', function (e) { apply(e.target.value); });
      var current = el.querySelector('input:checked, select');
      if (current && current.value !== '__all__') apply(current.value);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.qr-spike-filters').forEach(boot);
  });
})();
