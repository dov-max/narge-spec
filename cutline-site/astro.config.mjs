// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://dov-max.github.io',
  base: '/narge-spec',
  outDir: '../docs',
  build: {
    assets: 'assets'
  }
});
