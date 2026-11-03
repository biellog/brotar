import { describe, it, expect } from 'vitest';
import { pickUpdate } from '../../src/lib/updates.js';

const rel = (code, extra = {}) => ({ version_code: code, version_name: `1.${code}`, notes: '', url: 'https://github.com/biellog/brotar/releases', mandatory: false, ...extra });

describe('aviso de atualização', () => {
  it('nada a fazer quando já está na última versão', () => {
    expect(pickUpdate(5, [rel(3), rel(5)])).toBeNull();
    expect(pickUpdate(5, [])).toBeNull();
    expect(pickUpdate(5, null)).toBeNull();
  });
  it('mostra a versão mais nova', () => {
    expect(pickUpdate('5', [rel(6), rel(8), rel(7)]).version_code).toBe(8);
  });
  it('respeita "Depois" até sair uma versão ainda mais nova', () => {
    expect(pickUpdate(5, [rel(6)], 6)).toBeNull();
    expect(pickUpdate(5, [rel(6), rel(7)], 6).version_code).toBe(7);
  });
  it('versão obrigatória pulada não pode ser dispensada', () => {
    const up = pickUpdate(5, [rel(6, { mandatory: true }), rel(7)], 7);
    expect(up.version_code).toBe(7);
    expect(up.mandatory).toBe(true);
  });
  it('ignora linhas com URL insegura ou código inválido', () => {
    expect(pickUpdate(1, [rel(9, { url: 'javascript:alert(1)' }), rel(8, { url: 'http://x.com' }), rel('9')])).toBeNull();
  });
});
