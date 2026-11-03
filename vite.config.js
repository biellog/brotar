import { defineConfig } from 'vite';

// CSP estrita injetada só no build (o servidor de dev do Vite precisa de estilos inline).
const CSP = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data: blob:",
  "font-src 'self'",
  "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ');

export default defineConfig({
  base: './', // caminhos relativos: funciona no GitHub Pages (/brotar/) e no app Android
  build: { target: 'es2022', sourcemap: false },
  plugins: [{
    name: 'csp',
    apply: 'build',
    transformIndexHtml: (html) => html.replace('<meta charset="UTF-8" />',
      `<meta charset="UTF-8" />\n    <meta http-equiv="Content-Security-Policy" content="${CSP}" />`),
  }],
});
