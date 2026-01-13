from sqlalchemy.ext.asyncio import create_async_engine , AsyncSession
# from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, DeclarativeBase
import os
import sys
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
from core import config

# 設定ファイルからDB接続URLを取得
SQLALCHEMY_DATABASE_URL = config.settings.DATABASE_URL
# SQOLAlchemyエンジンを作成
engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    echo=True,
    pool_recycle=3600,    
)

# 各リクエストやワーカーでDB操作を行うためのセッションクラス
SessionLocal = sessionmaker(
    engine,
    class_ = AsyncSession,
    autocommit=False,
    autoflush=False, 
)

# すべてのモデルが継承するベースクラス
# Base = declarative_base()
class Base(DeclarativeBase):
    pass
# FastAPIの依存性注入で利用するDBセッション取得関数
async def get_db():
    db = SessionLocal()
    try:
        yield db

    finally:
        db.close()