import paho.mqtt.client as mqtt
import struct
import json
import time
import random
import os
import sys
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
from core import config
# あとでここ修正しておいて 直したよ


# 接続時のコールバック関数
def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"MQTTブローカーに接続成功: {config.settings.MQTT_HOST}:{config.settings.MQTT_PORT}")
    else:
        print(f"MQTTブローカーに接続失敗、エラーコード: {rc}")

# メッセージ送信用のクライアントを初期化
def connect_mqtt_publisher():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="elevator_publisher")
    client.on_connect = on_connect
    client.connect(config.settings.MQTT_HOST, config.settings.MQTT_PORT, keepalive=60) # keepaliveは接続維持の時間（秒）
    client.loop_start() # バックグラウンドでネットワークループを開始
    return client

# MQTTメッセージを公開する関数
def publish_elevator_status(client, topic, elevator_id):
    current_floor = random.randint(1, 10) # 1階から10階までのランダムな階
    occupancy = random.randint(0, 5)     # 0人から5人までのランダムな人数
    # direction = random.choice(["UP", "DOWN", "STOP"]) # ランダムな方向
    direction = random.randint(0,2)

    # 送信するデータをJSON形式で作成
    # payload = {
    #     "elevator_id": elevator_id,
    #     "current_floor": current_floor,
    #     "occupancy": occupancy,
    #     "direction": direction,
    #     "timestamp": time.time()
    # }
    # json_payload = struct.pack(json.dumps(payload))
    payload = struct.pack(
        config.settings.FORMAT_STR,
        elevator_id,
        current_floor,
        occupancy,
        direction
        # int(time.time())
        )
    json_payload = payload
    # print(json_payload.hex())
    # print(type(json_payload))
    # print(len(json_payload))
    print(struct.unpack(config.settings.FORMAT_STR,json_payload))
    # メッセージを公開
    result = client.publish(topic, json_payload, qos=1) # qos=1: 少なくとも1回は届ける
    status = result[0]
    if status == 0:
        print(f"トピック '{topic}' にメッセージを送信成功: {json_payload}")
    else:
        print(f"メッセージの送信に失敗、エラーコード: {status}")

if __name__ == "__main__":
    publisher_client = connect_mqtt_publisher()

    try:
        while True:
            # 複数の昇降機IDでデータを送信する例
            publish_elevator_status(publisher_client, config.settings.MQTT_TOPIC, 1)
            time.sleep(2) # 2秒待機

            # publish_elevator_status(publisher_client, config.settings.MQTT_TOPIC, 2)
            # time.sleep(2) # 2秒待機

            # publish_elevator_status(publisher_client, config.settings.MQTT_TOPIC, 3)
            # time.sleep(2) # 2秒待機

    except KeyboardInterrupt:
        print("発行を停止します。")
    finally:
        publisher_client.loop_stop() # ネットワークループを停止
        publisher_client.disconnect() # MQTTブローカーから切断
        print("MQTTクライアントを切断しました。")
