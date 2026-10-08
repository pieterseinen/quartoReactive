(function () {
  'use strict';

  // ================================================================
  // ReactiveDataStore
  //
  // Holds the full dataset, manages filters, and notifies
  // subscribers when the filtered data changes.
  // ================================================================
  class ReactiveDataStore {
    constructor(data, meta) {
      this._data         = Array.isArray(data) ? data : [];
      this._meta         = meta || {};
      this._filters      = new Map();
      this._rangeFilters = new Map();
      this._subscribers  = [];
      this._cache        = null;
    }

    setFilter(variable, values) {
      if (!values || values.length === 0) {
        this._filters.delete(variable);
      } else {
        this._filters.set(variable, new Set(values.map(String)));
      }
      this._invalidate();
    }

    setRangeFilter(variable, range) {
      this._rangeFilters.set(variable, range);
      this._invalidate();
    }

    clearFilter(variable) {
      this._filters.delete(variable);
      this._rangeFilters.delete(variable);
      this._invalidate();
    }

    clearAll() {
      this._filters.clear();
      this._rangeFilters.clear();
      this._invalidate();
    }

    getFilteredData() {
      if (this._cache) return this._cache;
      var rows = this._data;

      this._filters.forEach(function (allowed, variable) {
        rows = rows.filter(function (r) {
          var val = r[variable];
          return val != null && allowed.has(String(val));
        });
      });

      this._rangeFilters.forEach(function (range, variable) {
        rows = rows.filter(function (r) {
          var v = r[variable];
          return v != null && v >= range[0] && v <= range[1];
        });
      });

      this._cache = rows;
      return rows;
    }

    getFullData() { return this._data; }

    getColumnValues(variable) {
      return Array.from(new Set(this._data.map(function (r) { return r[variable]; })))
        .filter(function (v) { return v != null; })
        .sort();
    }

    getActiveFilters() {
      var result = {};
      this._filters.forEach(function (v, k) { result[k] = Array.from(v); });
      this._rangeFilters.forEach(function (v, k) { result[k] = v; });
      return result;
    }

    subscribe(callback) {
      this._subscribers.push(callback);
      callback(this.getFilteredData(), this.getActiveFilters());
      var self = this;
      return function () {
        self._subscribers = self._subscribers.filter(function (cb) { return cb !== callback; });
      };
    }

    _invalidate() {
      this._cache = null;
      var filtered = this.getFilteredData();
      var filters  = this.getActiveFilters();
      this._subscribers.forEach(function (cb) { cb(filtered, filters); });
    }
  }

  // ================================================================
  // Shared: guarded widget initialisation
  //
  // Tries HTMLWidgets.addPostRenderHandler + a 300ms setTimeout
  // fallback (the postRender callback may never fire when widgets
  // render before our boot script registers the handler).
  // ================================================================
  function whenWidgetReady(initFn) {
    var done = false;
    function guard() {
      if (done) return;
      done = true;
      initFn();
    }
    if (window.HTMLWidgets && HTMLWidgets.addPostRenderHandler) {
      HTMLWidgets.addPostRenderHandler(guard);
    }
    setTimeout(guard, 300);
  }

  // ================================================================
  // DataTableAdapter
  //
  // Subscribes to a ReactiveDataStore and updates a DT/DataTables
  // widget when the filtered data changes.
  // ================================================================
  class DataTableAdapter {
    constructor(widgetId, storeId, columns) {
      this.widgetId = widgetId;
      this.columns  = columns;
      this.storeId  = storeId;
      this._dt      = null;
      this._ready   = false;
      this._needsRowName = null;

      var self = this;
      var retryCount = 0;

      whenWidgetReady(function () {
        var wrapper = document.getElementById(widgetId);
        if (!wrapper) return;

        (function tryConnect() {
          retryCount++;
          try {
            if (typeof $ === 'undefined' || !$.fn.DataTable) {
              if (retryCount < 50) setTimeout(tryConnect, 200);
              return;
            }
            var table = $(wrapper).find('table');
            if (table.length && $.fn.DataTable.isDataTable(table)) {
              self._dt    = table.DataTable();
              self._ready = true;
              self._needsRowName = self._dt.columns().count() > self.columns.length;

              var store = window.__quartoReactive && window.__quartoReactive.stores[storeId];
              if (store) {
                store.subscribe(function (filteredData) { self._update(filteredData); });
              }
            } else if (retryCount < 50) {
              setTimeout(tryConnect, 200);
            }
          } catch (e) {
            if (retryCount < 50) setTimeout(tryConnect, 200);
          }
        })();
      });
    }

    _update(data) {
      if (!this._ready || !this._dt) return;
      this._dt.clear();
      var cols = this.columns;
      var needsRowName = this._needsRowName;
      data.forEach(function (row, idx) {
        var rowArr = cols.map(function (col) {
          var val = row[col];
          return val != null ? val : '';
        });
        if (needsRowName) rowArr.unshift(idx + 1);
        this._dt.row.add(rowArr);
      }.bind(this));
      this._dt.draw();
    }
  }

  // ================================================================
  // PlotlyAdapter
  //
  // Subscribes to a ReactiveDataStore and rebuilds Plotly traces
  // when the filtered data changes. Supports single-trace and
  // grouped (color) charts. Uses Plotly.react() for efficient
  // in-place updates that preserve layout (axes, title, margins).
  //
  // Supported chart types: scatter, bar, line (type + mode from spec).
  // ================================================================
  class PlotlyAdapter {
    constructor(divId, storeId, spec) {
      this.divId  = divId;
      this.spec   = spec;
      this._layout = null;

      var self = this;
      var retryCount = 0;

      whenWidgetReady(function () {
        var div = document.getElementById(divId);
        if (!div) return;

        (function tryConnect() {
          retryCount++;
          if (div.data && div.layout) {
            // Deep-copy layout so Plotly.react() doesn't mutate our reference
            self._layout = JSON.parse(JSON.stringify(div.layout));

            var store = window.__quartoReactive && window.__quartoReactive.stores[storeId];
            if (store) {
              store.subscribe(function (filteredData) { self._update(div, filteredData); });
            }
          } else if (retryCount < 50) {
            setTimeout(tryConnect, 200);
          }
        })();
      });
    }

    _update(div, data) {
      var traces = this._buildTraces(data);
      Plotly.react(div, traces, this._layout || div.layout || {});
    }

    _buildTraces(data) {
      var spec = this.spec;

      // --- No grouping: single trace ---
      if (!spec.color) {
        var trace = {
          x:    data.map(function (r) { return r[spec.x]; }),
          y:    data.map(function (r) { return r[spec.y]; }),
          type: spec.type || 'scatter',
          mode: spec.mode || 'markers'
        };
        if (spec.z)    trace.z      = data.map(function (r) { return r[spec.z]; });
        if (spec.size)  trace.marker = { size: data.map(function (r) { return r[spec.size]; }) };
        if (spec.text)  trace.text   = data.map(function (r) { return r[spec.text]; });
        return [trace];
      }

      // --- Grouped by color: one trace per unique value ---
      var groups = new Map();
      data.forEach(function (r) {
        var key = String(r[spec.color]);
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(r);
      });

      var traces = [];
      groups.forEach(function (rows, name) {
        var trace = {
          name: name,
          x:    rows.map(function (r) { return r[spec.x]; }),
          y:    rows.map(function (r) { return r[spec.y]; }),
          type: spec.type || 'scatter',
          mode: spec.mode || 'markers'
        };
        if (spec.z)    trace.z      = rows.map(function (r) { return r[spec.z]; });
        if (spec.size)  trace.marker = { size: rows.map(function (r) { return r[spec.size]; }) };
        if (spec.text)  trace.text   = rows.map(function (r) { return r[spec.text]; });
        traces.push(trace);
      });
      return traces;
    }
  }

  // ================================================================
  // Global namespace
  // ================================================================
  window.__quartoReactive = window.__quartoReactive || { stores: {} };

  window.ReactiveDataStore = ReactiveDataStore;
  window.DataTableAdapter  = DataTableAdapter;
  window.PlotlyAdapter     = PlotlyAdapter;

})();
