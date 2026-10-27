// Spike B: a per-group row-mask store plus adapters that hide rows/points in
// widgets R already rendered, so all R-side styling survives filtering.
(function () {
  'use strict';

  var stores = {};

  function store(group) {
    if (stores[group]) return stores[group];
    var filters = {};
    var subscribers = [];

    var s = stores[group] = {
      // null means no active filter: everything is visible.
      visible: function () {
        var result = null;
        Object.keys(filters).forEach(function (v) {
          var keys = filters[v];
          result = result === null
            ? new Set(keys)
            : new Set(keys.filter(function (k) { return result.has(k); }));
        });
        return result;
      },
      set:   function (v, keys) { filters[v] = keys; notify(); },
      clear: function (v) { delete filters[v]; notify(); },
      subscribe: function (fn) { subscribers.push(fn); fn(s.visible()); }
    };

    function notify() {
      var visible = s.visible();
      subscribers.forEach(function (fn) { fn(visible); });
    }
    return s;
  }

  function whenReady(test, fn) {
    var tries = 0;
    (function poll() {
      var ready = test();
      if (ready) fn(ready);
      else if (++tries < 100) setTimeout(poll, 50);
    })();
  }

  window.qrSpikeSink = function (group, variable) {
    var s = store(group);
    return {
      set:   function (keys) { s.set(variable, keys); },
      clear: function () { s.clear(variable); }
    };
  };

  // ---- DT: a DataTables search hook scoped to this table -----------------

  window.qrMaskDT = function (id, group, keys) {
    whenReady(function () {
      var table = document.querySelector('#' + id + ' table');
      return table && $.fn.dataTable.isDataTable(table) && table;
    }, function (table) {
      var visible = null;
      // dataIndex is the row's position in the widget's own data.
      function keyOf(i) { return keys ? keys[i] : String(i + 1); }
      $.fn.dataTable.ext.search.push(function (settings, rowData, dataIndex) {
        return settings.nTable !== table || visible === null || visible.has(keyOf(dataIndex));
      });
      var dt = $(table).DataTable();
      store(group).subscribe(function (v) { visible = v; dt.draw(); });
    });
  };

  // ---- plotly: filter the per-point arrays of the original traces ---------

  var PER_POINT        = ['x', 'y', 'z', 'text', 'hovertext', 'customdata', 'ids', 'key'];
  var PER_POINT_MARKER = ['color', 'size', 'symbol', 'opacity'];

  function filterTrace(trace, visible) {
    var keys = trace.key;
    if (visible === null || !Array.isArray(keys)) return trace;

    var keep = [];
    keys.forEach(function (k, i) { if (visible.has(String(k))) keep.push(i); });
    var n = keys.length;
    function pick(arr) { return keep.map(function (i) { return arr[i]; }); }

    var out = Object.assign({}, trace);
    PER_POINT.forEach(function (a) {
      if (Array.isArray(trace[a]) && trace[a].length === n) out[a] = pick(trace[a]);
    });
    if (trace.marker) {
      out.marker = Object.assign({}, trace.marker);
      PER_POINT_MARKER.forEach(function (a) {
        if (Array.isArray(trace.marker[a]) && trace.marker[a].length === n) out.marker[a] = pick(trace.marker[a]);
      });
    }
    return out;
  }

  window.qrMaskPlotly = function (id, group) {
    whenReady(function () {
      var div = document.getElementById(id);
      return div && div.data && div.layout && div;
    }, function (div) {
      var original = JSON.parse(JSON.stringify(div.data));
      var layout = JSON.parse(JSON.stringify(div.layout));
      store(group).subscribe(function (visible) {
        Plotly.react(div, original.map(function (t) { return filterTrace(t, visible); }), layout);
      });
    });
  };
})();
