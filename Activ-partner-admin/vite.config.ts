import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, '.', 'VITE_')
  if (command === 'build' && !env.VITE_API_URL?.trim() && !env.VITE_LOCAL_API_URL?.trim()) {
    throw new Error('Missing API URL: set VITE_API_URL in your hosting environment before building (or VITE_LOCAL_API_URL for local use).')
  }

  return {
    plugins: [react()],
    server: {
      port: 5173,
    },
  }
})
