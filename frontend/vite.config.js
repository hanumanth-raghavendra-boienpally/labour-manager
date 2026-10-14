import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The /api proxy (used when VITE_API_BASE_URL is empty) sends API calls to the Spring Boot backend on port 10000.
export default defineConfig({
  plugins: [react()],
  server: { port: 10001, strictPort: true, proxy: { '/api': 'http://localhost:10000' } },
  preview: { port: 4173, proxy: { '/api': 'http://localhost:10000' } },
});
