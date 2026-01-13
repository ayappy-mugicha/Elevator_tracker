import asyncio
import os
import sys
import traceback
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# from app.database.database import SQLALCHEMY_DATABASE_URL, Base, engine
from app.database import database

async def create_db_tables():
    print("データベーステーブルの作成を開始します")
    print(f"作成するデータベースのURL: {database.SQLALCHEMY_DATABASE_URL}")
    async with database.engine.begin() as conn:
        await conn.run_sync(database.Base.metadata.create_all)
        print("テーブル作成処理が完了しました")
        await database.engine.dispose()

if __name__ == "__main__":
    try:
        asyncio.run(create_db_tables())
    except Exception as e:
        print(f"テーブル作成中にエラーが発生しました {type(e)}")
        traceback.print_exc()