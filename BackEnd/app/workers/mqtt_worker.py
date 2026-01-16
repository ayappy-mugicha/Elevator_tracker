from paho.mqtt import client as mqtt_client
import os
import sys
import traceback
import asyncio
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
from database import crud , database
from core import config
import json
import time


# グローバルなイベントループ
worker_loop = None

# 非同期でDB保存を行う関数
async def save_data_async(data):
    async with database.SessionLocal() as db:
        await crud.create_elevator_status(db, data)
        await db.commit()

# コールバック関数の定義

def on_connect(client,userdata, flags, rc, properties=None): 
    if rc == 0:
        print("接続完了" + str(rc))
        client.subscribe(config.settings.MQTT_TOPIC)
        print(f"トピック {config.settings.MQTT_TOPIC} を購読中")
    else:
        print("接続失敗" + str(rc))
        
def on_message(client, userdata, msg, properties=None):
    try:
        data = json.loads(msg.payload.decode()) # jsonでMQTTのデータを読み取る
        if worker_loop:
            future = asyncio.run_coroutine_threadsafe(save_data_async(data), worker_loop)
            future.result()
        print(f"DBにデータを保存: timestamp={data['timestamp']} EID={data['elevator_id']} 階={data['current_floor']} 人数={data['occupancy']} 方向={data['direction']}")

    except Exception as e:
        print(f"MQTT処理エラー:{e}")
        traceback.print_exc()

def run_mqtt_worker():
    global worker_loop
    worker_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(worker_loop)

    client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION2, client_id = "fastapi_worker")
    
    # コールバック関数を登録
    client.on_message = on_message
    client.on_connect = on_connect

    # 設定ファイルから接続情報を取得
    broker_host = config.settings.MQTT_HOST
    broker_port = config.settings.MQTT_PORT

    while True:
        try:
            client.connect(broker_host,broker_port)
            break
        except Exception as e:
            print(f"エラーが発生しました {e}")
            traceback.print_exc()
            time.sleep(5)

    client.loop_start()
    try:
        worker_loop.run_forever()
    finally:
        client.loop_stop()
        worker_loop.close()

if __name__ == "__main__":
    run_mqtt_worker()