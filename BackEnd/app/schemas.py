from pydantic import BaseModel
from datetime import datetime

class ElevatorStatusSchema(BaseModel):
    """ フロントエンドへ返すエレベーターの状態スキーマ """

    current_floor: int
    occupancy: int
    direction: str # "UP" "DOWN" "IDLE"
    timestamp: datetime # DB格納時刻

    # SQLAlchemyモデルからPydanticモデルへの変換を許可する設定
    model_config = {
        "front_attributes": True
    }