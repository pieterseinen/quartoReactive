// Spike A sink: each input owns a crosstalk FilterHandle; crosstalk intersects
// the handles of a group and the widgets (DT, plotly) react natively.
window.qrSpikeSink = function (group) {
  var handle = new crosstalk.FilterHandle(group);
  var last = null;
  // Workaround: plotly's crosstalk binding ignores a filter set before it has
  // subscribed, so defaults are re-applied once everything has loaded.
  window.addEventListener('load', function () {
    setTimeout(function () { if (last) { handle.clear(); handle.set(last); } }, 0);
  });
  return {
    set:   function (keys) { last = keys; handle.set(keys); },
    clear: function () { last = null; handle.clear(); }
  };
};
