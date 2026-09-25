import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig(({ command }) => ({
  plugins: [vue()],
  // SPA is served by IRIS from /iris-operations/, so production asset URLs
  // must be prefixed. Dev runs at the Vite root and proxies the API instead.
  base: command === 'build' ? '/iris-operations/' : '/',
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/iris-operations': {
        target: 'http://localhost:52773',
        changeOrigin: true
      }
    }
  }
}))
