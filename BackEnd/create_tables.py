import asyncio
import os
import sys
import traceback
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# from app.database.database import SQLALCHEMY_DATABASE_URL, Base, engine
from app.database import database
from app.database import models

async def create_database():
    """データベースが存在しない場合に作成する"""
    # 設定からURLオブジェクトを作成
    url_obj = make_url(database.SQLALCHEMY_DATABASE_URL)
    db_name = url_obj.database

    # データベース名を空にしてサーバー接続用のURLを作成
    # これにより特定のDBに依存せずに接続する
    server_url = url_obj.set(database="")

    print(f"データベース '{db_name}' の存在を確認・作成します...")

    # 一時的なエンジンを作成
    temp_engine = create_async_engine(server_url, echo=True)

    try:
        async with temp_engine.connect() as conn:
            # CREATE DATABASE は AUTOCOMMIT モードで実行する必要がある
            await conn.execution_options(isolation_level="AUTOCOMMIT")
            await conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{db_name}`"))
            print(f"データベース '{db_name}' の準備が完了しました。")
    finally:
        await temp_engine.dispose()

async def create_db_tables():
    # テーブル作成の前にデータベースを作成
    await create_database()

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