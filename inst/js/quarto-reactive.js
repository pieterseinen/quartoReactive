(function () {
  'use strict';

  var QR_DEBUG = true;  // ← flip to false to silence diagnostics
  function log(/* ...args */) {
    if (QR_DEBUG) console.log.apply(console, ['[qr]'].concat(Array.prototype.slice.call(arguments)));
  }
  function warn(/* ...args */) {
    console.warn.apply(console, ['[qr]'].concat(Array.prototype.slice.call(arguments)));
  }

  log('JS bundle loaded — defining classes');

  // ════════════════════════════════════════════════════════════════
  // ReactiveDataStore
  //
  // Holds the full dataset, manages filters, and notifies
  // subscribers when the filtered data changes.
  // ════════════════════════════════════════════════════════════════
  class ReactiveDataStore {
    constructor(data, meta) {
      this._data          = Array.isArray(data) ? data : [];
      this._meta          = meta || {};
      this._filters       = new Map();   // variable → Set<value> (categorical)
      this._rangeFilters  = new Map();   // variable → [min, max] (numeric)
      this._subscribers   = [];
      this._cache         = null;
      log('ReactiveDataStore created —', this._data.length, 'rows,',
          'columns:', Object.keys(this._data[0] || {}));
    }

    // ── Filter API (called by inputs) ──────────────────────────

    setFilter(variable, values) {
      log('setFilter("' + variable + '",', JSON.stringify(values) + ')');
      if (!values || values.length === 0) {
        this._filters.delete(variable);
      } else {
        // Coerce to strings for consistent matching
        this._filters.set(variable, new Set(values.map(String)));
      }
      this._invalidate();
    }

    setRangeFilter(variable, range) {
      this._rangeFilters.set(variable, range);
      this._invalidate();
    }

    clearFilter(variable) {
      log('clearFilter("' + variable + '")');
      this._filters.delete(variable);
      this._rangeFilters.delete(variable);
      this._invalidate();
    }

    clearAll() {
      this._filters.clear();
      this._rangeFilters.clear();
      this._invalidate();
    }

    // ── Data access (called by adapters) ───────────────────────

    getFilteredData() {
      if (this._cache) return this._cache;

      let rows = this._data;

      // Apply categorical filters
      for (const [variable, allowed] of this._filters) {
        rows = rows.filter(r => {
          const val = r[variable];
          return val != null && allowed.has(String(val));
        });
      }

      // Apply range filters
      for (const [variable, [min, max]] of this._rangeFilters) {
        rows = rows.filter(r => {
          const v = r[variable];
          return v != null && v >= min && v <= max;
        });
      }

      this._cache = rows;
      return rows;
    }

    getFullData() {
      return this._data;
    }

    getColumnValues(variable) {
      return [...new Set(this._data.map(r => r[variable]))]
        .filter(v => v != null)
        .sort();
    }

    getActiveFilters() {
      const result = {};
      for (const [k, v] of this._filters) result[k] = [...v];
      for (const [k, v] of this._rangeFilters) result[k] = v;
      return result;
    }

    // ── Subscription (called by adapters) ──────────────────────

    subscribe(callback) {
      this._subscribers.push(callback);
      log('subscribe() — total subscribers now:', this._subscribers.length);
      // Fire immediately with current data
      callback(this.getFilteredData(), this.getActiveFilters());
      // Return unsubscribe function
      return () => {
        this._subscribers = this._subscribers.filter(cb => cb !== callback);
      };
    }

    // ── Internal ───────────────────────────────────────────────

    _invalidate() {
      this._cache = null;
      const filtered = this.getFilteredData();
      const filters  = this.getActiveFilters();
      log('_invalidate() — filters:', JSON.stringify(filters),
          '— filtered', filtered.length, '/', this._data.length, 'rows',
          '— notifying', this._subscribers.length, 'subscribers');
      this._subscribers.forEach(cb => cb(filtered, filters));
    }
  }

  // ════════════════════════════════════════════════════════════════
  // DataTableAdapter
  //
  // Subscribes to a ReactiveDataStore and updates a DT/DataTables
  // widget when the filtered data changes.
  // ════════════════════════════════════════════════════════════════
  class DataTableAdapter {
    constructor(widgetId, storeId, columns) {
      log('DataTableAdapter() — widgetId:', widgetId,
          'storeId:', storeId, 'columns:', JSON.stringify(columns));

      this.widgetId = widgetId;
      this.columns  = columns;
      this.storeId  = storeId;
      this._dt      = null;
      this._ready   = false;

      const self = this;
      var retryCount = 0;

      // Wait for htmlwidgets to finish rendering, then subscribe
      function init() {
        log('DataTableAdapter.init() called');
        const wrapper = document.getElementById(widgetId);
        if (!wrapper) {
          warn('DT wrapper not found:', widgetId,
               '— all IDs on page:', Array.from(document.querySelectorAll('[id]')).map(function(e) { return e.id; }).filter(function(id) { return id.indexOf('qr') >= 0 || id.indexOf('dt') >= 0 || id.indexOf('DT') >= 0 || id.indexOf('DataTables') >= 0 || id.indexOf('htmlwidget') >= 0; }));
          return;
        }
        log('DataTableAdapter — wrapper found:', wrapper.tagName, wrapper.className);

        // DT (via htmlwidgets) stores the DataTable instance
        // Try to find it via jQuery DataTables API
        var tryConnect = function () {
          retryCount++;
          try {
            var jqAvail = typeof $ !== 'undefined';
            var dtAvail = jqAvail && $.fn && $.fn.DataTable;
            if (!jqAvail) {
              log('DataTableAdapter — jQuery not available yet (retry', retryCount + ')');
              if (retryCount < 50) setTimeout(tryConnect, 200);
              else warn('DataTableAdapter — gave up waiting for jQuery after', retryCount, 'retries');
              return;
            }
            var table = $(wrapper).find('table');
            var isInit = dtAvail && table.length && $.fn.DataTable.isDataTable(table);
            log('DataTableAdapter — tryConnect #' + retryCount + ':',
                'jQuery:', jqAvail, 'DataTable plugin:', !!dtAvail,
                'table found:', table.length > 0, 'isDataTable:', isInit);

            if (isInit) {
              self._dt = table.DataTable();
              self._ready = true;
              log('DataTableAdapter — connected to DT instance');

              // Now subscribe to the store
              var store = window.__quartoReactive && window.__quartoReactive.stores[storeId];
              if (store) {
                log('DataTableAdapter — subscribing to store', storeId);
                store.subscribe(function (filteredData) {
                  self._update(filteredData);
                });
              } else {
                warn('DataTableAdapter — store not found:', storeId,
                     '— available stores:', Object.keys(window.__quartoReactive ? window.__quartoReactive.stores : {}));
              }
            } else {
              // Retry — DT may not be initialized yet
              if (retryCount < 50) setTimeout(tryConnect, 200);
              else warn('DataTableAdapter — gave up waiting for DT init after', retryCount, 'retries');
            }
          } catch (e) {
            warn('DataTableAdapter — tryConnect error:', e.message);
            if (retryCount < 50) setTimeout(tryConnect, 200);
          }
        };

        tryConnect();
      }

      // Strategy: try HTMLWidgets postRender AND a polling fallback.
      // addPostRenderHandler may never fire if widgets rendered before
      // our boot script ran (race condition with DOMContentLoaded order).
      var _initDone = false;
      function guardedInit() {
        if (_initDone) return;
        _initDone = true;
        init();
      }

      var hwAvail = window.HTMLWidgets && HTMLWidgets.addPostRenderHandler;
      log('DataTableAdapter — HTMLWidgets available:', !!hwAvail,
          'readyState:', document.readyState);

      if (hwAvail) {
        HTMLWidgets.addPostRenderHandler(guardedInit);
      }
      // Always also poll as fallback — tryConnect retries if DT isn't ready yet
      setTimeout(guardedInit, 300);
    }

    _update(data) {
      if (!this._ready || !this._dt) {
        log('DataTableAdapter._update() — skipped (ready:', this._ready, 'dt:', !!this._dt + ')');
        return;
      }

      log('DataTableAdapter._update() —', data.length, 'rows,',
          'columns:', JSON.stringify(this.columns));

      // Detect if DT has a row-names column (more columns in the table than
      // in our data spec). DT prepends row names as column index 0.
      var dtColCount = this._dt.columns().count();
      var needsRowName = dtColCount > this.columns.length;
      if (!this._loggedRowName) {
        log('DataTableAdapter — DT columns:', dtColCount,
            'data columns:', this.columns.length,
            'needsRowName:', needsRowName);
        this._loggedRowName = true;
      }

      // Log a sample row to check data shape
      if (data.length > 0) {
        var sampleRow = data[0];
        var mapped = {};
        this.columns.forEach(function(col) { mapped[col] = sampleRow[col]; });
        log('DataTableAdapter — sample row mapped:', JSON.stringify(mapped));
      }

      this._dt.clear();

      data.forEach(function(row, idx) {
        // Build row array in column order
        var rowArr = this.columns.map(function(col) {
          var val = row[col];
          return val != null ? val : '';
        });
        // Prepend row name if DT expects one
        if (needsRowName) rowArr.unshift(idx + 1);
        this._dt.row.add(rowArr);
      }.bind(this));

      this._dt.draw();
      log('DataTableAdapter._update() — draw complete');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Global namespace
  // ════════════════════════════════════════════════════════════════
  window.__quartoReactive = window.__quartoReactive || { stores: {} };

  // Expose classes globally so boot scripts can instantiate them
  window.ReactiveDataStore = ReactiveDataStore;
  window.DataTableAdapter  = DataTableAdapter;

  log('Classes exposed globally — ReactiveDataStore:', typeof window.ReactiveDataStore,
      'DataTableAdapter:', typeof window.DataTableAdapter);

})();
