import { defineConfig } from "vitest/config";

// Relative base so the build works from the GitHub Pages project path.
export default defineConfig({
  base: "./",
  test: {
    include: ["tests/**/*.test.ts"],
  },
});
