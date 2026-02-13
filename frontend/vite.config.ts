import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // .env ファイルから環境変数を読み込む
  const env = loadEnv(mode, path.resolve(__dirname, '../'), '');
  // バックエンドのホスト名を環境変数から取得。なければ'localhost'を使う
  const backendHost = env.BACKEND_HOST;
  const backendPort = parseInt(env.BACKEND_PORT);
  const backendurl = `ws://${backendHost}:${backendPort}`;
  const frontendHost = env.HOST;
  const frontendPort = parseInt(env.VITE_PORT);


  return {
    plugins: [react()],
    server: {
      host: frontendHost, // 外部からのアクセスを許可
      port: frontendPort,
      proxy: {
        '/ws/elevator': {
          target: backendurl,
          ws: true,
        },
      },
      // HMR (Hot Module Replacement) が外部IPからのアクセスでも機能するように設定
      // 'localhost'への固定を解除し、Viteが接続元のホストを自動的に使用するようにします
      hmr: {
        host: backendHost,
        port: frontendPort,
        clientPort: frontendPort,
      }
    }
  }
})
