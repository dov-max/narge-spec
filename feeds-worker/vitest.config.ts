import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        // Test-only value. Production uses `wrangler secret put COUNTER_SECRET`.
        bindings: { COUNTER_SECRET: "test-only-not-a-real-secret-0123456789abcdef", K_MIN: "10" },
      },
    }),
  ],
});
