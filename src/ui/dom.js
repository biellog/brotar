// Helper de DOM sem innerHTML: todo texto vira TextNode, então dados do usuário nunca viram HTML.
const SVG_NS = 'http://www.w3.org/2000/svg';
const SVG_TAGS = new Set(['svg', 'g', 'path', 'circle', 'ellipse', 'rect', 'line', 'polygon', 'defs', 'linearGradient', 'radialGradient', 'stop', 'text']);

export function h(tag, props = {}, ...children) {
  const el = SVG_TAGS.has(tag) ? document.createElementNS(SVG_NS, tag) : document.createElement(tag);
  for (const [k, v] of Object.entries(props ?? {})) {
    if (v == null || v === false) continue;
    if (/^on/i.test(k)) { if (typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v); continue; } // nunca handler em string
    else if (k === 'class') el.setAttribute('class', v);
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (/^(href|src|action|formaction)$/i.test(k) && /^\s*javascript:/i.test(String(v))) continue; // bloqueia URLs javascript:
    else if (k in el && !SVG_TAGS.has(tag) && typeof v !== 'string') el[k] = v;
    else el.setAttribute(k, v === true ? '' : String(v));
  }
  append(el, children);
  return el;
}

function append(el, children) {
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
}

export function clear(el) { while (el.firstChild) el.firstChild.remove(); return el; }
