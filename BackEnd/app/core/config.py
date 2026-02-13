from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path
from dotenv import load_dotenv
from typing import Optional

# プロジェクトのルートディレクトリを指定
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent

# .envファイルを明示的に読み込み、変数展開（Interpolation）を有効にする
# これにより、.env内で ${VAR} 形式の参照が可能になります
load_dotenv(f"{BASE_DIR}/.env")

class Settings(BaseSettings):
    """ 環境変数を管理するためのPydanticモデル """

    # DB接続情報
    DB_DRIVER: str = "mysql+aiomysql"
    DB_USER: str
    DB_PASSWORD: str
    DB_HOST: str
    DB_PORT: int
    DB_NAME: str   

    # DATABASE_URL: Optional[str] = None
    @property
    def DATABASE_URL(self) -> str:
        return (
            f"{self.DB_DRIVER}://"
            f"{self.DB_USER}:{self.DB_PASSWORD}@"
            f"{self.DB_HOST}:{self.DB_PORT}/"
            f"{self.DB_NAME}"
        )

    # MQTT接続情報
    MQTT_HOST: str
    MQTT_PORT: int
    MQTT_TOPIC: str
    FORMAT_STR: str
    
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), # .envファイルの場所を指定
        env_file_encoding='utf-8', # .envファイルのエンコーディングを指定
        extra='ignore' # 定義されていない環境変数があっても無視する
    )

    # def __init__(self, **kwargs):
    #     super().__init__(**kwargs)
    #     # DATABASE_URLが明示的に設定されていない場合、自動生成する
    #     if not self.DATABASE_URL:
    #         self.DATABASE_URL = (
    #             f"{self.DB_DRIVER}://"
    #             f"{self.DB_USER}:{self.DB_PASSWORD}@"
    #             f"{self.DB_HOST}:{self.DB_PORT}/"
    #             f"{self.DB_NAME}"
    #         )

# 設定をアプリケーション全体で利用できるようにインスタンス化
settings = Settings()