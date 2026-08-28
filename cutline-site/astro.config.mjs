// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://thecutline.org',
  base: '/',
  outDir: '../docs',
  build: {
    assets: 'assets'
  }
});
