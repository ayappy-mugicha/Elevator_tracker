from paho.mqtt import client as mqtt_client
from ..database.crud import create_elevator_status
from ..database.database import SessionLocal # DBセッションをワーカー内で取得
from ..core.config import settings
import json
import time


# コールバック関数の定義

def on_connect(client,userdata, flags, rc): 
    if rc == 0:
        print("接続完了" + str(rc))
        client.subscribe(settings.MQTT_TOPIC)
        print(f"トピック {settings.MQTT_TOPIC} を購読中")
    else:
        print("接続失敗" + str(rc))
        
def on_message(clinet, userdata, msg):
    try:
        data = json.loads(msg.payload.decode()) # jsonでMQTTのデータを読み取る
        db = SessionLocal() # 新しいセッションを開始
        try:
            # CRUD関数を呼び出しDBにデータを保存
            crud.create_elevator_status(db, data)
            print(f"DBにデータを保存: EID={data['elevator_id']} 階={data['current_floor']} 人数={data['occupancy']} 方向={data['direction']}")
        
        finally:
            db.close()

    except Exception as e:
        print(f"MQTT処理エラー:{e}")

def run_mqtt_worker():
    client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION1, client_id = "fastapi_worker")
    
    # コールバック関数を登録
    client.on_message = on_message
    client.on_connect = on_connect

    # 設定ファイルから接続情報を取得
    broker_host = settings.MQTT_HOST
    broker_port = settings.MQTT_PORT

    while True:
        try:
            client.connect("mqtt_broker_host",1883)
            client.loop_forever() # ブロッキングして常駐プロセスとして実行
        except Exception as e:
            print(f"エラーが発生しました {e}")
            time.sleep(5)

if __name__ == "__main__":
    run_mqtt_worker()