set -e

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
# 仮想環境の有効化
ACTIVATE_VENV="$PROJECT_ROOT/Elevetor/bin/activate"
# 実行中のプロセスを追跡するためのPIDファイルを各のするディレクトリ
PID_DIR="$PROJECT_ROOT/run"
mkdir -p "$PID_DIR"

PID_MQTT="$PID_DIR/mqtt_worker.pid"
PID_FASTAPI="$PID_DIR/fastapi_server.pid"
PID_REACT="$PID_DIR/react_dev.pid" 
# スクリプト終了時にすべてのバックグラウンドプロセスを終了させる関数
cleanup(){
    echo ""
    echo "システムをシャットダウン中"

    # PIDファイルからプロセスIDを読み取り、終了させる

    if [ -f "$PID_MQTT" ]; then
        kill $(cat "$PID_MQTT") 2>/dev/null || true
    fi
    if [ -f "$PID_FASTAPI" ]; then
        kill $(cat "$PID_FASTAPI") 2>/dev/null || true
    fi
    if [ -f "$PID_REACT" ]; then
        kill $(cat "$PID_REACT") 2>/dev/null || true
    fi

    # PIDファイルを削除
    rm -f "$PID_MQTT" "$PID_FASTAPI" "$PID_REACT"
    echo "すべてのプロセスが停止しました"
    exit 0
}

# crl+C が押されたcleanup関数を呼び出す
trap 'cleanup' SIGINT

echo "---バックエンドを起動---"

#仮想環境を有効化

if [ -f "$ACTIVATE_VENV" ]; then
    echo "仮想環境を有効化完了"
    . "$ACTIVATE_VENV"

else
    echo "仮想環境が見つかりません: $ACITVATE_VENV"
    exit 1
fi

# MQTTワーカーを起動
echo "--MQTTワーカーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/BackEnd"
    python app/workers/mqtt_worker.py $ 2> /dev/null &
    echo $! > "$PID_MQTT" #PIDをファイルに保存
)
echo ""
echo "--MQTTワーカー起動完了--"
echo "--Fastapi サーバーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/BackEnd/"
    uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    echo $! > "$PID_FASTAPI" # PID をファイルに保存
)
echo ""
echo "--fastapiサーバー起動完了--"
echo "サーバーが起動するのを待機中"
sleep 5 # サーバー起動を待つために数秒待機

echo "---フロントエンド起動---"

echo "--react開発サーバーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/frontend"
    npm run dev $ #2> /dev/null $
    echo $! > "$PID_REACT" # pidをファイルに保存
)

echo "起動完了"
echo "システムが稼働中です。ctrl+Cですべてを停止します"
echo ""

echo "フロントエンド: http://localhost:3000"
echo "FastAPIDocs: http://localhost:3000/docs"

# メインプロセスを維持しctrl+C 入力を待機する
wait