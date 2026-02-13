from asyncio import Server
from sqlite3.dbapi2 import Timestamp
from time import timezone
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, DateTime
from sqlalchemy.sql import func
from .database import Base

class ElevatorStatus(Base):
    """ エレベーターの状態を格納するテーブル """

    __tablename__ = "elevator_status"
    
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