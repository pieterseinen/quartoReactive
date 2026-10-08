(function () {
  'use strict';

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
    }

    // ── Filter API (called by inputs) ──────────────────────────

    setFilter(variable, values) {
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
      this.widgetId = widgetId;
      this.columns  = columns;
      this.storeId  = storeId;
      this._dt      = null;
      this._ready   = false;

      const self = this;

      // Wait for htmlwidgets to finish rendering, then subscribe
      function init() {
        const wrapper = document.getElementById(widgetId);
        if (!wrapper) {
          console.warn('[quartoReactive] DT wrapper not found:', widgetId);
          return;
        }

        // DT (via htmlwidgets) stores the DataTable instance
        // Try to find it via jQuery DataTables API
        const tryConnect = function () {
          try {
            const table = $(wrapper).find('table');
            if (table.length && $.fn.DataTable.isDataTable(table)) {
              self._dt = table.DataTable();
              self._ready = true;

              // Now subscribe to the store
              const store = window.__quartoReactive && window.__quartoReactive.stores[storeId];
              if (store) {
                store.subscribe(function (filteredData) {
                  self._update(filteredData);
                });
              }
            } else {
              // Retry — DT may not be initialized yet
              setTimeout(tryConnect, 100);
            }
          } catch (e) {
            setTimeout(tryConnect, 100);
          }
        };

        tryConnect();
      }

      // Use HTMLWidgets postRender if available, otherwise DOMContentLoaded
      if (window.HTMLWidgets && HTMLWidgets.addPostRenderHandler) {
        HTMLWidgets.addPostRenderHandler(init);
      } else {
        if (document.readyState === 'complete') init();
        else window.addEventListener('load', init);
      }
    }

    _update(data) {
      if (!this._ready || !this._dt) return;

      this._dt.clear();

      data.forEach(row => {
        // Build row array in column order
        const rowArr = this.columns.map(col => {
          const val = row[col];
          return val != null ? val : '';
        });
        this._dt.row.add(rowArr);
      });

      this._dt.draw();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Global namespace
  // ════════════════════════════════════════════════════════════════
  window.__quartoReactive = window.__quartoReactive || { stores: {} };

  // Expose classes globally so boot scripts can instantiate them
  window.ReactiveDataStore = ReactiveDataStore;
  window.DataTableAdapter  = DataTableAdapter;

})();
