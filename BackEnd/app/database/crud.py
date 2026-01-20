from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from . import models
from typing import Dict, Any, List

async def create_elevator_status(db: AsyncSession, data: Dict[str, Any]) -> models.ElevatorStatus:
    """
    MQTTから受信したデータをDBに新規レコードとして保存する。

    :param db: データベースセッション
    :param data: MQTTペイロード(辞書型)
    :return: 作成されたデータベースオブジェクト
    """

    db_status = models.ElevatorStatus(
        # エレベータID
        # elevator_id = data.get("elevator_id","E1"),
        elevator_id=data["elevator_id"],
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

async def get_latest_elevator_status(db: AsyncSession) -> models.ElevatorStatus | None:
    """
    データベース内の最新ステータスレコードを1件取得する。

    :param db: データベースセッション
    :return: 最新のElevatorStatus オブジェクト、または存在しない場合はNone
    """
    reslut = await db.execute( # DBの関数を使っている。内容はほとんどDBのコマンドと変わらなそう。
        select(models.ElevatorStatus).order_by(models.ElevatorStatus.timestamp.desc()) # タイムスタンプでソ降順ソート
    )
    return reslut.scalars().first()

async def get_multi_elevator_statuses(db: AsyncSession) -> List[models.ElevatorStatus]:
    """
    各エレベーターIDごとに、最新のステータスを取得してリストで返す
    """
    # サブクエリ: IDごとの最新時刻を取得
    subq = (
        select(
            models.ElevatorStatus.elevator_id,
            func.max(models.ElevatorStatus.timestamp).label("max_ts")
        )
        .group_by(models.ElevatorStatus.elevator_id)
        .subquery()
    )

    # メインクエリ: IDと時刻が一致する行を取得
    stmt = (
        select(models.ElevatorStatus)
        .join(subq, (models.ElevatorStatus.elevator_id == subq.c.elevator_id) & (models.ElevatorStatus.timestamp == subq.c.max_ts))
        .order_by(models.ElevatorStatus.elevator_id)
    )
    
    result = await db.execute(stmt)
    return result.scalars().all()

def get_recent_status_list(db: AsyncSession, limit: int = 10) -> List[models.ElevatorStatus]:
    """
    最新から遡って複数のステータスレコードを取得する(グラフ表示などに利用可能)
    """

    return(
        db.query(models.ElevatorStatus)
        .order_by(models.ElevatorStatus.timestamp.desc())
        .limit(limit)
        .all()
    )