from asyncio import Server
from sqlite3.dbapi2 import Timestamp
from time import timezone
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, DateTime
from sqlalchemy.sql import func
from database.database import Base
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
from core import config

class ElevatorStatus(Base):
    """ エレベーターの状態を格納するテーブル """

    __tablename__ = config.settings.DB_TABLE
    
    # id = column(Integer, primary_key = True, index = True)
    id: Mapped[int] = mapped_column(Integer, primary_key = True, index=True)
    # エレベーターの識別子(複数台対応の場合)
    elevator_id: Mapped[str] = mapped_column(String(10),nullable=False)
    # elevator_id = column(String(50), index=True, default="E1")

    # 現在の階層
    current_floor: Mapped[int] = mapped_column(Integer, nullable=False)
    # current_floor = column(Integer, nullable=False)

    # 搭乗人数
    occupancy: Mapped[int] = mapped_column(Integer, nullable=False)
    # occupancy = column(Integer, nullable = False)

    # 進行方向 ("UP","DOWN","IDLE")
    direction: Mapped[str] = mapped_column(String(10), nullable=False)
    # direction = column(String(50), nullable= False)

    # データが作成された時刻(DB側で自動設定)
    timestamp: Mapped[DateTime] = mapped_column(DateTime(timezone=True),server_default = func.now()) 
    # timestamp = column(DateTime(timezone=True), server_default = func.now())

    def __repr__(self):
        return (f"<ElevatorStatus(id={self.id}, floor={self.current_floor}, "
                f"occupancy={self.occupancy}, direction='{self.direction}')>")