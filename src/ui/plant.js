// Cena do jardim em SVG: a planta principal cresce conforme os dias sóbrios.
import { h } from './dom.js';

const THEMES = {
  dia: { sky: ['#bfe9ff', '#f1fbef'], ground: '#7cc576', ground2: '#5aa85a', sun: '#ffd54f' },
  noite: { sky: ['#0f1a3d', '#33406e'], ground: '#2f5a3a', ground2: '#244a2f', sun: '#f4f1c9' },
  outono: { sky: ['#ffd9a8', '#fff3e0'], ground: '#c99a52', ground2: '#a87a3a', sun: '#ff8a50' },
  aurora: { sky: ['#1b1446', '#2bb59c'], ground: '#3a6b5a', ground2: '#2a5546', sun: '#b9f6ca' },
};

export function plantScene(stage, theme = 'dia') {
  const t = THEMES[theme] ?? THEMES.dia;
  const night = theme === 'noite' || theme === 'aurora';
  const parts = [];

  const stem = (x1, y1, x2, y2, w = 5) => h('path', { d: `M${x1} ${y1} Q ${x1 + (x2 - x1) * 0.3 - 6} ${(y1 + y2) / 2} ${x2} ${y2}`, stroke: '#2e7d32', 'stroke-width': w, fill: 'none', 'stroke-linecap': 'round' });
  const leaf = (x, y, rot, s = 1, c = '#43a047') => h('ellipse', { cx: x, cy: y, rx: 14 * s, ry: 7 * s, fill: c, transform: `rotate(${rot} ${x} ${y})` });
  const flower = (x, y, c = '#ffb74d', s = 1) => h('g', {},
    ...[0, 72, 144, 216, 288].map((a) => h('ellipse', { cx: x, cy: y - 7 * s, rx: 5 * s, ry: 8 * s, fill: c, transform: `rotate(${a} ${x} ${y})` })),
    h('circle', { cx: x, cy: y, r: 4.5 * s, fill: '#6d4c41' }));

  const gx = 160; const gy = 190;
  if (stage === 0) {
    parts.push(h('ellipse', { cx: gx, cy: gy - 4, rx: 9, ry: 6, fill: '#8d6e63' }), h('path', { d: `M${gx} ${gy - 10} q 3 -6 7 -5`, stroke: '#7cb342', 'stroke-width': 3, fill: 'none', 'stroke-linecap': 'round' }));
  } else if (stage <= 2) {
    const top = stage === 1 ? 160 : 140;
    parts.push(stem(gx, gy, gx, top, 4), leaf(gx - 11, top + 4, -30, stage === 1 ? 0.8 : 1), leaf(gx + 11, top + 2, 30, stage === 1 ? 0.8 : 1));
    if (stage === 2) parts.push(leaf(gx - 12, top + 22, -20, 0.9), leaf(gx + 12, top + 24, 20, 0.9));
  } else if (stage <= 4) {
    const top = stage === 3 ? 115 : 95;
    parts.push(stem(gx, gy, gx, top, stage === 3 ? 5 : 7));
    const n = stage === 3 ? 4 : 7;
    for (let i = 0; i < n; i++) {
      const y = gy - 18 - i * ((gy - top - 10) / n);
      parts.push(leaf(gx + (i % 2 ? 14 : -14), y, i % 2 ? 25 : -25, 1.1));
    }
    parts.push(stage === 3 ? leaf(gx, top - 4, 90, 0.9) : flower(gx, top - 6, '#ffca28', 1.3));
    if (stage === 4) parts.push(flower(gx - 30, 135, '#f48fb1', 0.9), flower(gx + 30, 128, '#ce93d8', 0.9));
  } else {
    // árvore
    parts.push(h('path', { d: `M${gx - 9} ${gy} L ${gx - 6} 110 L ${gx + 6} 110 L ${gx + 9} ${gy} Z`, fill: '#795548' }),
      h('path', { d: `M${gx} 130 L ${gx - 28} 105 M ${gx} 120 L ${gx + 30} 98`, stroke: '#795548', 'stroke-width': 5, 'stroke-linecap': 'round' }));
    const crown = theme === 'outono' ? ['#ef6c00', '#ffa726', '#d84315'] : ['#388e3c', '#43a047', '#66bb6a'];
    [[gx, 78, 46], [gx - 36, 98, 32], [gx + 38, 92, 34], [gx - 10, 58, 30], [gx + 18, 62, 28]].forEach(([x, y, r], i) =>
      parts.push(h('circle', { cx: x, cy: y, r, fill: crown[i % 3] })));
    if (stage === 6) {
      [[gx - 20, 60], [gx + 25, 70], [gx - 45, 95], [gx + 50, 90], [gx, 95], [gx + 10, 45], [gx - 30, 80]].forEach(([x, y]) =>
        parts.push(flower(x, y, '#fff59d', 0.7)));
    }
  }

  const stars = night ? [[30, 30], [80, 18], [250, 25], [290, 60], [210, 15], [120, 40]].map(([x, y]) => h('circle', { cx: x, cy: y, r: 1.6, fill: '#fff' })) : [];

  return h('svg', { viewBox: '0 0 320 220', class: 'scene', role: 'img', 'aria-label': 'Sua planta' },
    h('defs', {}, h('linearGradient', { id: 'sky', x1: 0, y1: 0, x2: 0, y2: 1 },
      h('stop', { offset: '0', 'stop-color': t.sky[0] }), h('stop', { offset: '1', 'stop-color': t.sky[1] }))),
    h('rect', { x: 0, y: 0, width: 320, height: 220, fill: 'url(#sky)' }),
    ...stars,
    h('circle', { cx: 270, cy: 42, r: 18, fill: t.sun, opacity: 0.95 }),
    h('path', { d: 'M0 180 Q 80 160 160 178 T 320 172 V220 H0 Z', fill: t.ground }),
    h('path', { d: 'M0 200 Q 100 188 200 200 T 320 196 V220 H0 Z', fill: t.ground2 }),
    h('g', { class: 'plant' }, ...parts));
}
