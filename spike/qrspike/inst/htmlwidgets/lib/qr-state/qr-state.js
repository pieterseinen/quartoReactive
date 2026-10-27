// Book-wide selection store. Named params (e.g. "gemeente") hold arrays of keys.
// State persists in sessionStorage, so it survives switching chapters, and is
// mirrored to the URL query so a comparison can be shared as a link (the URL
// wins on load). Loaded from the book header and as a widget dependency, so it
// guards against running twice.
(function () {
  'use strict';
  if (window.qrState) return;

  var STORAGE_KEY = 'qr-state';
  var config = {};
  var values = {};
  var subscribers = {};

  function readStorage() {
    try { return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || {}; } catch (e) { return {}; }
  }
  function writeStorage() {
    try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(values)); } catch (e) {}
  }
  function readUrl(param) {
    var raw = new URLSearchParams(location.search).get(param);
    return raw === null ? null : raw.split(',').filter(Boolean);
  }
  function writeUrl() {
    var url = new URL(location.href);
    Object.keys(values).forEach(function (p) { url.searchParams.set(p, values[p].join(',')); });
    history.replaceState(history.state, '', url);
  }

  var stored = readStorage();

  function resolve(param) {
    if (param in values) return;
    values[param] = readUrl(param) || stored[param] || (config[param] && config[param].default) || [];
  }

  var qrState = window.qrState = {
    configure: function (param, options) { config[param] = options || {}; },
    get: function (param) { resolve(param); return values[param].slice(); },
    set: function (param, keys) {
      values[param] = keys.slice();
      writeStorage();
      writeUrl();
      (subscribers[param] || []).forEach(function (fn) { fn(values[param].slice()); });
    },
    // Calls fn immediately with the current value, then on every change.
    subscribe: function (param, fn) {
      (subscribers[param] = subscribers[param] || []).push(fn);
      fn(qrState.get(param));
      return function () {
        subscribers[param] = subscribers[param].filter(function (f) { return f !== fn; });
      };
    },
    // Keys that stay visible whatever is selected (e.g. a national benchmark).
    always: function (param) { return (config[param] && config[param].always) || []; }
  };

  // ---- Inputs: any element with data-qr-param ---------------------------

  function bootInput(el) {
    var param  = el.dataset.qrParam;
    var select = el.querySelector('select');
    var boxes  = Array.from(el.querySelectorAll('input'));

    function read() {
      if (select) return Array.from(select.selectedOptions).map(function (o) { return o.value; });
      return boxes.filter(function (b) { return b.checked; }).map(function (b) { return b.value; });
    }

    el.addEventListener('change', function () { qrState.set(param, read()); });
    qrState.subscribe(param, function (keys) {
      if (select) Array.from(select.options).forEach(function (o) { o.selected = keys.indexOf(o.value) >= 0; });
      else boxes.forEach(function (b) { b.checked = keys.indexOf(b.value) >= 0; });
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

  function bridge(param) {
    var handle = new crosstalk.FilterHandle(param);
    function apply(keys) {
      if (keys.length === 0) handle.clear();
      else handle.set(keys.concat(qrState.always(param)));
      // plotly redraws on the filter event; trim once it has.
      setTimeout(trimCategoryAxes, 0);
    }
    qrState.subscribe(param, apply);
    // plotly ignores a filter set before it subscribed: re-apply after load.
    window.addEventListener('load', function () {
      setTimeout(function () { handle.clear(); apply(qrState.get(param)); }, 0);
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    Object.keys(config).forEach(function (p) { resolve(p); });
    writeStorage();
    writeUrl();
    document.querySelectorAll('[data-qr-param]').forEach(bootInput);
    if (window.crosstalk) Object.keys(config).forEach(bridge);
  });
})();
