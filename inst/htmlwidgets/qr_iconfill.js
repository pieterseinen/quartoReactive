// One icon per visible key, filled bottom-up to its percentage. Subscribes to
// window.qrState directly; no crosstalk involved.
//
// The icon is used as a mask over two rectangles: the background and the
// fill. The fill is sized to the icon's drawn shape (getBBox), so a value of
// 50% fills half the shape whatever empty space the icon's viewBox has.
// Icons that appear (page load, selection change) fill up from empty while
// their number counts up; icons that stay visible are left as they are.
HTMLWidgets.widget({
  name: 'qr_iconfill',
  type: 'output',

  factory: function (el) {
    var SVG = 'http://www.w3.org/2000/svg';
    var unsubscribe = null;
    var figures = {};   // key -> { figure, fill, number, color }
    var uid = 0;

    var reduceMotion = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function easeOut(t) { return 1 - Math.pow(1 - t, 3); }

    function format(x, value) {
      if (value === null) return '–';
      return value.toFixed(x.digits).replace('.', x.decimal) + x.suffix;
    }

    function svgEl(name, attrs) {
      var e = document.createElementNS(SVG, name);
      Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
      return e;
    }

    // Builds the figure for one key; returns the parts to animate.
    function build(x, i) {
      var id = (el.id || 'qr-iconfill') + '-' + (uid++);
      var size = x.size;
      var svg = svgEl('svg', { viewBox: x.icon.viewBox, height: size, 'aria-hidden': 'true' });
      svg.style.overflow = 'visible';

      // An invisible copy of the icon, drawn only to measure its shape.
      var probe = svgEl('g', { opacity: '0', fill: '#000', color: '#000' });
      probe.innerHTML = x.icon.content;
      svg.appendChild(probe);

      var mask = svgEl('mask', { id: id, maskUnits: 'userSpaceOnUse' });
      var shape = svgEl('g', { fill: '#fff', color: '#fff' });
      shape.innerHTML = x.icon.content;
      mask.appendChild(shape);
      var defs = svgEl('defs', {});
      defs.appendChild(mask);
      svg.appendChild(defs);

      var masked = svgEl('g', { mask: 'url(#' + id + ')' });
      var back = svgEl('rect', { fill: x.background });
      var fill = svgEl('rect', { class: 'qr-icon-fill' });
      masked.appendChild(back);
      masked.appendChild(fill);
      svg.appendChild(masked);

      var figure = document.createElement('figure');
      figure.className = 'qr-icon';
      figure.dataset.key = x.keys[i];
      var caption = document.createElement('figcaption');
      var name = document.createElement('span');
      name.textContent = x.labels[i];
      var number = document.createElement('strong');
      caption.appendChild(name);
      caption.appendChild(document.createElement('br'));
      caption.appendChild(number);
      figure.appendChild(svg);
      figure.appendChild(caption);

      return { figure: figure, svg: svg, probe: probe, back: back, fill: fill, number: number };
    }

    // Sizes the rectangles to the icon's shape; needs the figure in the page.
    function measure(x, parts) {
      var box;
      try { box = parts.probe.getBBox(); } catch (e) { box = null; }
      if (!box || !box.width || !box.height) {
        var vb = x.icon.viewBox.split(/[\s,]+/).map(Number);
        box = { x: vb[0], y: vb[1], width: vb[2], height: vb[3] };
      }
      // Width in pixels follows the aspect ratio of the viewBox.
      var vb2 = x.icon.viewBox.split(/[\s,]+/).map(Number);
      parts.svg.setAttribute('width', Math.round(x.size * vb2[2] / vb2[3]));
      parts.box = box;
      [parts.back, parts.fill].forEach(function (r) {
        r.setAttribute('x', box.x);
        r.setAttribute('width', box.width);
      });
      parts.back.setAttribute('y', box.y);
      parts.back.setAttribute('height', box.height);
    }

    function draw(x, parts, value, progress) {
      var pct = value === null ? 0 : Math.max(0, Math.min(100, value)) / 100;
      var h = parts.box.height * pct * progress;
      parts.fill.setAttribute('y', parts.box.y + parts.box.height - h);
      parts.fill.setAttribute('height', h);
      parts.number.textContent = format(x, value === null ? null : value * progress);
    }

    // An icon in a hidden container (e.g. a closed tab) cannot be measured
    // yet, so it is measured again when it becomes visible.
    function animate(x, parts, value) {
      if (reduceMotion || !x.duration || value === null) {
        draw(x, parts, value, 1);
        whenVisible(parts.figure, function () {
          measure(x, parts);
          draw(x, parts, value, 1);
        });
        return;
      }
      draw(x, parts, value, 0);
      var start = null;
      function step(now) {
        if (!parts.figure.isConnected) return;
        if (start === null) start = now;
        var t = Math.min(1, (now - start) / x.duration);
        draw(x, parts, value, easeOut(t));
        if (t < 1) requestAnimationFrame(step);
      }
      whenVisible(parts.figure, function () {
        measure(x, parts);
        requestAnimationFrame(step);
      });
    }

    // Icons further down the page fill up once the reader scrolls to them.
    function whenVisible(target, fn) {
      if (!window.IntersectionObserver) { fn(); return; }
      var observer = new IntersectionObserver(function (entries) {
        if (!entries.some(function (e) { return e.isIntersecting; })) return;
        observer.disconnect();
        fn();
      }, { threshold: 0.5 });
      observer.observe(target);
    }

    function render(x, selected) {
      var shown = window.qrState.visible(x.param, selected) || x.keys;
      var keep = {};
      x.keys.forEach(function (key, i) {
        if (shown.indexOf(key) < 0) return;
        keep[key] = true;
        var parts = figures[key];
        var fresh = !parts;
        if (fresh) parts = figures[key] = build(x, i);
        parts.fill.setAttribute('fill', window.qrState.color(x.param, key) || x.color);
        el.appendChild(parts.figure);   // (re)appends in data order
        if (fresh) {
          measure(x, parts);
          animate(x, parts, x.values[i]);
        }
      });
      Object.keys(figures).forEach(function (key) {
        if (keep[key]) return;
        figures[key].figure.remove();
        delete figures[key];
      });
    }

    return {
      renderValue: function (x) {
        if (unsubscribe) unsubscribe();
        el.textContent = '';
        figures = {};
        el.classList.add('qr-iconfill');
        unsubscribe = window.qrState.subscribe(x.param, function (selected) { render(x, selected); });
      },
      resize: function () {}
    };
  }
});
