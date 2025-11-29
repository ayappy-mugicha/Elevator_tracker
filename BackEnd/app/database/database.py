from sqlalchemy.ext.asyncio import create_async_engine , AsyncSession
# from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from ..core.config import settings

# 設定ファイルからDB接続URLを取得
SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL
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