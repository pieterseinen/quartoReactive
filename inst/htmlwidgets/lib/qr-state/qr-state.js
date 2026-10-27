// quartoReactive selection store. Named params (e.g. "gemeente") hold arrays of
// keys. State persists in sessionStorage, so it survives switching chapters of
// a book, and is mirrored to the URL query so a selection can be shared as a
// link (the URL wins on load). The script can be loaded more than once on a
// page (book header and widget dependencies), so it guards against that.
(function () {
  'use strict';
  if (window.qrState) return;

  var namespace = '';
  var config = {};
  var values = {};
  // Colour slot per selected key, per param: a key keeps its slot while it
  // stays selected, so other series are never repainted by a change.
  var slots = {};
  var subscribers = {};
  var stored = null;

  function storageKey() { return 'qr-state' + (namespace ? ':' + namespace : ''); }

  function readStorage() {
    if (stored === null) {
      try { stored = JSON.parse(sessionStorage.getItem(storageKey())) || {}; } catch (e) { stored = {}; }
      stored.values = stored.values || {};
      stored.slots = stored.slots || {};
    }
    return stored;
  }
  function writeStorage() {
    try {
      sessionStorage.setItem(storageKey(), JSON.stringify({ values: values, slots: slots }));
    } catch (e) {}
  }
  function readUrl(param) {
    var raw = new URLSearchParams(location.search).get(param);
    return raw === null ? null : raw.split(',').filter(Boolean);
  }
  function writeUrl() {
    var url = new URL(location.href);
    Object.keys(values).forEach(function (p) { url.searchParams.set(p, values[p].join(',')); });
    // Keep commas readable in shared links.
    history.replaceState(history.state, '', url.href.replace(/%2C/gi, ','));
  }

  // Gives new keys the lowest free slot and frees the slots of dropped keys.
  function assignSlots(param) {
    var old = slots[param] || {};
    var next = {};
    var taken = [];
    values[param].forEach(function (k) {
      if (k in old) { next[k] = old[k]; taken.push(old[k]); }
    });
    values[param].forEach(function (k) {
      if (k in next) return;
      var slot = 0;
      while (taken.indexOf(slot) >= 0) slot++;
      next[k] = slot;
      taken.push(slot);
    });
    slots[param] = next;
  }

  // At most `max` keys (if configured); later keys are dropped.
  function limit(param, keys) {
    var max = config[param] && config[param].max;
    return max ? keys.slice(0, max) : keys;
  }

  function resolve(param) {
    if (param in values) return;
    var saved = readStorage();
    values[param] = limit(param, readUrl(param) || saved.values[param] ||
      (config[param] && config[param].default) || []);
    slots[param] = saved.slots[param] || {};
    assignSlots(param);
  }

  var qrState = window.qrState = {
    // Separates the stored state of different books on one site. Call before
    // anything reads state.
    namespace: function (id) { namespace = id || ''; stored = null; },
    configure: function (param, options) { config[param] = options || {}; },
    get: function (param) { resolve(param); return values[param].slice(); },
    // Keys keep the order in which they were selected (inputs report them in
    // display order), so over `max` the newest are dropped.
    set: function (param, keys) {
      resolve(param);
      var kept = values[param].filter(function (k) { return keys.indexOf(k) >= 0; });
      keys.forEach(function (k) { if (kept.indexOf(k) < 0) kept.push(k); });
      values[param] = limit(param, kept);
      assignSlots(param);
      writeStorage();
      writeUrl();
      (subscribers[param] || []).forEach(function (fn) { fn(values[param].slice()); });
    },
    // Calls fn immediately with the current value, then on every change.
    // Returns a function that unsubscribes.
    subscribe: function (param, fn) {
      (subscribers[param] = subscribers[param] || []).push(fn);
      fn(qrState.get(param));
      return function () {
        subscribers[param] = subscribers[param].filter(function (f) { return f !== fn; });
      };
    },
    // Keys that stay visible whatever is selected (e.g. a national benchmark).
    always: function (param) { return (config[param] && config[param].always) || []; },
    max: function (param) { return (config[param] && config[param].max) || null; },
    // What a widget should show: the selection plus `always`, or null for
    // "everything" when nothing is selected.
    visible: function (param, keys) {
      var selected = keys || qrState.get(param);
      return selected.length ? selected.concat(qrState.always(param)) : null;
    },
    // Colour of a selected key when the param has `colors`, else null.
    color: function (param, key) {
      var palette = config[param] && config[param].colors;
      resolve(param);
      if (!palette || !palette.length || !(key in slots[param])) return null;
      return palette[slots[param][key] % palette.length];
    }
  };

  // ---- Inputs: any element with data-qr-param ---------------------------

  function bootInput(el) {
    if (el.dataset.qrBooted) return;
    el.dataset.qrBooted = 'true';
    var param  = el.dataset.qrParam;
    var select = el.querySelector('select');
    var boxes  = Array.from(el.querySelectorAll('input'));
    var max    = qrState.max(param);

    if (select && select.dataset.qrSearch !== undefined && window.TomSelect) {
      bootSearch(el, param, select, max);
      return;
    }

    function read() {
      if (select) return Array.from(select.selectedOptions).map(function (o) { return o.value; });
      return boxes.filter(function (b) { return b.checked; }).map(function (b) { return b.value; });
    }

    el.addEventListener('change', function () { qrState.set(param, read()); });
    qrState.subscribe(param, function (keys) {
      if (select) Array.from(select.options).forEach(function (o) { o.selected = keys.indexOf(o.value) >= 0; });
      else boxes.forEach(function (b) {
        b.checked = keys.indexOf(b.value) >= 0;
        // At the maximum, only deselecting is possible.
        if (b.type === 'checkbox') b.disabled = !b.checked && max !== null && keys.length >= max;
      });
    });
  }

  // A <select> with data-qr-search becomes a Tom Select: type to filter,
  // chips with a remove button for multiple choice.
  function bootSearch(el, param, select, max) {
    var multiple = select.multiple;
    var ts = new TomSelect(select, {
      plugins: multiple ? ['remove_button'] : [],
      maxItems: multiple ? max : 1,
      placeholder: select.dataset.qrPlaceholder || '',
      hidePlaceholder: false,
      closeAfterSelect: !multiple
    });
    var syncing = false;
    ts.on('change', function () {
      if (syncing) return;
      var v = ts.getValue();
      qrState.set(param, Array.isArray(v) ? v : (v ? [v] : []));
    });
    qrState.subscribe(param, function (keys) {
      syncing = true;
      ts.setValue(multiple ? keys : keys.slice(0, 1), true);
      syncing = false;
    });
  }

  // ---- Selection bar: chips for the current selection --------------------

  function bootBar(el) {
    if (el.dataset.qrBooted) return;
    el.dataset.qrBooted = 'true';
    var param  = el.dataset.qrBar;
    var labels = JSON.parse(el.dataset.qrLabels || '{}');
    var list   = el.querySelector('.qr-chips');
    var remove = el.dataset.qrRemove || 'Remove';

    function chip(key) {
      var li = document.createElement('li');
      li.className = 'qr-chip';
      li.dataset.key = key;
      var color = qrState.color(param, key);
      if (color) li.style.setProperty('--qr-chip-color', color);
      var text = document.createElement('span');
      text.textContent = labels[key] || key;
      var button = document.createElement('button');
      button.type = 'button';
      button.textContent = '×';
      button.setAttribute('aria-label', remove + ' ' + (labels[key] || key));
      button.addEventListener('click', function () {
        qrState.set(param, qrState.get(param).filter(function (k) { return k !== key; }));
      });
      li.appendChild(text);
      li.appendChild(button);
      return li;
    }

    // Quarto's fixed header (narrow screens) slides in and out on scroll:
    // stick just below it while it shows.
    var header = document.getElementById('quarto-header');
    if (el.classList.contains('qr-sticky') && header) {
      var place = function () {
        el.style.top = Math.max(0, header.getBoundingClientRect().bottom) + 'px';
      };
      window.addEventListener('scroll', place, { passive: true });
      window.addEventListener('resize', place);
      header.addEventListener('transitionend', place);
      place();
    }

    qrState.subscribe(param, function (keys) {
      list.textContent = '';
      el.classList.toggle('qr-empty', keys.length === 0);
      keys.forEach(function (k) { list.appendChild(chip(k)); });
    });
  }

  // ---- Crosstalk bridge: plotly/DT/leaflet follow a param via the group of
  // the same name; their SharedData key holds the param's values. -----------

  // R's plotly_build() pins category axes to every level (categoryorder
  // "array"), so plotly.js keeps empty slots for filtered-out categories that
  // sort between visible ones. Shrink each pinned axis to the categories still
  // present, in R's original order.
  var pinnedAxes = new Map();

  function trimCategoryAxes() {
    if (!window.Plotly) return;
    document.querySelectorAll('.plotly.html-widget').forEach(function (div) {
      if (!div.layout || !div.data) return;
      var update = {};
      ['xaxis', 'yaxis'].forEach(function (axis) {
        var ax = div.layout[axis];
        if (!ax || ax.categoryorder !== 'array') return;
        var key = div.id + ':' + axis;
        if (!pinnedAxes.has(key)) pinnedAxes.set(key, (ax.categoryarray || []).slice());
        var letter = axis.charAt(0);
        var present = new Set();
        div.data.forEach(function (t) { (t[letter] || []).forEach(function (v) { present.add(String(v)); }); });
        update[axis + '.categoryarray'] = pinnedAxes.get(key).filter(function (c) { return present.has(String(c)); });
        update[axis + '.autorange'] = true;
      });
      if (Object.keys(update).length) Plotly.relayout(div, update);
    });
  }

  // With selection colours, a plotly trace that holds a single selected key
  // (e.g. one line per municipality) takes that key's colour.
  function recolorTraces(param) {
    if (!window.Plotly || !(config[param] && config[param].colors)) return;
    document.querySelectorAll('.plotly.html-widget').forEach(function (div) {
      if (!div.data) return;
      var indices = [], lines = [], markers = [];
      div.data.forEach(function (t, i) {
        if (t.set !== param || !t.key || !t.key.length) return;
        var key = String(t.key[0]);
        if (t.key.some(function (k) { return String(k) !== key; })) return;
        var color = qrState.color(param, key);
        if (!color) return;
        indices.push(i); lines.push(color); markers.push(color);
      });
      if (indices.length) Plotly.restyle(div, { 'line.color': lines, 'marker.color': markers }, indices);
    });
  }

  function bridge(param) {
    var handle = new crosstalk.FilterHandle(param);
    function apply(keys) {
      var shown = qrState.visible(param, keys);
      if (shown) handle.set(shown); else handle.clear();
      // plotly redraws on the filter event; adjust once it has.
      setTimeout(function () { trimCategoryAxes(); recolorTraces(param); }, 0);
    }
    qrState.subscribe(param, apply);
    // plotly ignores a filter set before it subscribed: re-apply after load.
    window.addEventListener('load', function () {
      setTimeout(function () { handle.clear(); apply(qrState.get(param)); }, 0);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    var inputs = Array.from(document.querySelectorAll('[data-qr-param]'));
    var bars = Array.from(document.querySelectorAll('[data-qr-bar]'));
    var params = Object.keys(config);
    inputs.forEach(function (el) {
      if (params.indexOf(el.dataset.qrParam) < 0) params.push(el.dataset.qrParam);
    });
    params.forEach(resolve);
    writeStorage();
    writeUrl();
    inputs.forEach(bootInput);
    bars.forEach(bootBar);
    if (window.crosstalk) params.forEach(bridge);
  });
})();
