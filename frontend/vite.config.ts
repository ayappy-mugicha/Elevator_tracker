import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // .env ファイルから環境変数を読み込む
  const env = loadEnv(mode, process.cwd(), '');
  // バックエンドのホスト名を環境変数から取得。なければ'localhost'を使う
  const backendHost = env.VITE_BACKEND_HOST || 'localhost';

  return {
    plugins: [react()],
    server: {
      host: '0.0.0.0', // 外部からのアクセスを許可
      port: 5173,
      strictPort: true,
      cors: true,
      proxy: {
        '/ws/elevator': {
          target: `ws://${backendHost}:8000`,
          ws: true,
        },
      },
      // HMR (Hot Module Replacement) が外部IPからのアクセスでも機能するように設定
      // 'localhost'への固定を解除し、Viteが接続元のホストを自動的に使用するようにします
      hmr: {
        host: backendHost,
        protocol: 'ws',
        port: 5173,
      },
      watch: {
        usePolling: true,
      },
    },
  }
})
