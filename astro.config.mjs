// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  // Hide Astro's floating dev toolbar so it doesn't clutter the preview (or the projector).
  devToolbar: { enabled: false },
  vite: {
    plugins: [tailwindcss()],
    server: {
      // The page talks to "/helper" on its own address, and this passes the
      // message on to the helper program (npm run helper) on this computer.
      proxy: {
        '/helper': {
          target: 'http://127.0.0.1:4330',
          rewrite: (path) => path.replace(/^\/helper/, ''),
        },
      },
    },
  },
});
