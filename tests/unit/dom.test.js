// @vitest-environment jsdom
import { describe, it, expect } from 'vitest';
import { h } from '../../src/ui/dom.js';

describe('h() — proteção contra XSS', () => {
  it('texto nunca vira HTML', () => {
    const el = h('div', {}, '<img src=x onerror=alert(1)>');
    expect(el.querySelector('img')).toBeNull();
    expect(el.textContent).toBe('<img src=x onerror=alert(1)>');
  });
  it('bloqueia href javascript:', () => {
    expect(h('a', { href: 'javascript:alert(1)' }).getAttribute('href')).toBeNull();
    expect(h('a', { href: '  JaVaScRiPt:alert(1)' }).getAttribute('href')).toBeNull();
    expect(h('a', { href: 'tel:188' }).getAttribute('href')).toBe('tel:188');
  });
  it('eventos só via função', () => {
    const el = h('button', { onclick: 'alert(1)' });
    expect(el.onclick).toBeNull();
  });
  it('atributo com aspas não escapa', () => {
    const el = h('input', { placeholder: '"><script>x</script>' });
    expect(el.getAttribute('placeholder')).toBe('"><script>x</script>');
    expect(el.children).toHaveLength(0);
    expect(el.outerHTML).toContain('&quot;'); // aspas escapadas: não fecha o atributo
  });
});
