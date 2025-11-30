import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api.routes import router
from .database.database import engine, Base
from .database import models # models.pyをインポートすることでテーブル定義を認識させる

# データベースにテーブルが存在しない場合、ここで作成
# 本番環境ではAlembicなどのマイグレーションツールを推奨

# FastAPIアプリケーションのインスタンス化
app = FastAPI(title="Elevator Monitoring API")

# CORS (Cross-Origin Resource Sharing) 設定
# Reactフロントエンドからのアクセスを許可するために必須
# 開発環境ではlocalhost:3000を許可
origins = [
    "http://localhost:3000",  # Reactのデフォルト開発サーバーのポート
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ルーターをアプリケーションに含める
app.include_router(router)

# ルートパス
@app.get("/")
def read_root():
    return {"message": "Elevator Monitoring System Backend is running"}