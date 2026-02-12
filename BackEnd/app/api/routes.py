import asyncio
import os
import sys
import traceback
from fastapi import APIRouter, Depends, WebSocket, HTTPException, WebSocketDisconnect
from sqlalchemy.orm import Session
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
print(parent_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
from database import crud ,database
# from database.database import get_db , SessionLocal
from schemas import ElevatorStatusSchema # Pydanticスキーマをインポート

router = APIRouter()

@router.get("/latest_status", response_model=ElevatorStatusSchema)
def read_latest_status_http(db: Session = Depends(database.get_db)):
    """ DBから最新のステータスを1件取得し、HTTPで返す (主にデバッグ用 """
    latest_status = crud.get_latest_elevator_status(db)
    if not latest_status:
        print("No elevator status found in the database.", flush=True)
        raise HTTPException(status_code=404, detail = "No elevator status found")
    
    # Pydanticスキーマにデータをマッピングして返す
    return latest_status

@router.websocket("/ws/elevator")
async def websocket_endpoint(websocket: WebSocket):
    """
    websocketクライアント接続を受け入れ、DBの最新データを定期的にプッシュする
    """
    await websocket.accept()
    print("websocketクライアントが接続しました", flush=True)

    try:
        # DB への負担を考慮し、ボーリング間隔を0.5秒に設定
        POLL_INTERVAL = 0.5

        while True:
            db = database.SessionLocal()
            try:
                # 最新データをDBから取得 (全台分)
                latest_statuses = await crud.get_multi_elevator_statuses(db)

                if latest_statuses:
                    response_data = []
                    for status in latest_statuses:
                        response_data.append({
                            "elevator_id": status.elevator_id,
                            "current_floor": status.current_floor,
                            "occupancy": status.occupancy,
                            "direction": status.direction,
                            "timestamp": str(status.timestamp),
                        })

                    # JSON形式でクライアントにデータをプッシュ (リスト形式)
                    await websocket.send_json(response_data)
                
                # 指定時間待機
                
            finally:
                await db.close() # DBクローズ
            
            # 指定時間待機
            await asyncio.sleep(POLL_INTERVAL)

    except WebSocketDisconnect:
        print("websocketクライアントが切断しました", flush=True)
    except Exception as e:
        print(f"websocket処理中にエラーが発生: {e}", flush=True)
        traceback.print_exc()
    finally:
        await websocket.close()