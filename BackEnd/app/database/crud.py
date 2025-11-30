
import select
from sqlalchemy.ext.asyncio import AsyncSession
from .models import ElevatorStatus
from typing import Dict, Any, List

async def create_elevator_status(db: AsyncSession, data: Dict[str, Any]) -> ElevatorStatus:
    """
    MQTTから受信したデータをDBに新規レコードとして保存する。

    :param db: データベースセッション
    :param data: MQTTペイロード(辞書型)
    :return: 作成されたデータベースオブジェクト
    """

    db_status = ElevatorStatus(
        # エレベータID
        elevator_id = data.get("elevator_id","E1"),
        # 階層
        current_floor=data["current_floor"],
        # 人数
        occupancy=data["occupancy"],
        # 進行方向
        direction=data["direction"],
        # timestampはDB側で自動生成されるため、ここでは省略可能
    )

    db.add(db_status)
    await db.commit()
    await db.refresh(db_status)
    return db_status

async def get_latest_elevator_status(db: AsyncSession) -> ElevatorStatus | None:
    """
    データベース内の最新ステータスレコードを1件取得する。

    :param db: データベースセッション
    :return: 最新のElevatorStatus オブジェクト、または存在しない場合はNone
    """
    reslut = await db.execute(
        select(ElevatorStatus)
        .order_by(ElevatorStatus.timestamp.desc()) # タイムスタンプでソ降順ソート
        .limit(1)
    )
    return reslut.scalars().first()

def get_recent_status_list(db: AsyncSession, limit: int = 10) -> List[ElevatorStatus]:
    """
    最新から遡って複数のステータスレコードを取得する(グラフ表示などに利用可能)
    """

    return(
        db.query(ElevatorStatus)
        .order_by(ElevatorStatus.timestamp.desc())
        .limit(limit)
        .all()
    )