set -e

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
# 仮想環境設定
VENV_NAME="Elevetor"
REQUIREMENTS=BackEnd/requirements.txt
LOG_DIR="$PROJECT_ROOT/logs" # ログファイル用のディレクトリを定義
FRONTEND_DATA="$PROJECT_ROOT/frontend/node_modules"
ACTIVATE_VENV="$PROJECT_ROOT/$VENV_NAME/bin/activate"

PID_DIR="$PROJECT_ROOT/run"
mkdir -p "$PID_DIR"
mkdir -p "$LOG_DIR" # ログディレクトリを作成

# 実行中のプロセスを追跡するためのPIDファイルを各のするディレクトリ
PID_MQTT="$PID_DIR/mqtt_worker.pid"
PID_FASTAPI="$PID_DIR/fastapi_server.pid"
PID_REACT="$PID_DIR/react_dev.pid"
# スクリプト終了時にすべてのバックグラウンドプロセスを終了させる関数
cleanup(){
    echo ""
    echo "システムをシャットダウン中"

    # PIDファイルからプロセスIDを読み取り、終了させる
    if [ -f "$PID_MQTT" ]; then
        kill -TERM -- -$(cat "$PID_MQTT") 2>/dev/null || true
    fi
    if [ -f "$PID_FASTAPI" ]; then
        kill -TERM -- -$(cat "$PID_FASTAPI") 2>/dev/null || true
    fi
    if [ -f "$PID_REACT" ]; then
        kill -TERM -- -$(cat "$PID_REACT") 2>/dev/null || true
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
    . $ACTIVATE_VENV

else
    echo "仮想環境が見つかりません: $ACTIVATE_VENV"
    read -p "仮想環境を構築しますか [y/n]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo "仮想環境を構築します"
        python3 -m venv "$VENV_NAME"
        . $ACTIVATE_VENV
        echo "仮想環境の有効化完了"
        sleep 1
        echo "仮想環境の有効化をしました。続いてモジュールをインポートします"
        sleep 5
        pip install -r "$REQUIREMENTS" # REQUIREMENTS変数を引用符で囲む
        echo "モジュールをインポートできました"
    else
        echo "了解です。終了します"
        exit 1
    fi

fi

# MQTTワーカーを起動
echo "--MQTTワーカーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/BackEnd"
    # setsid を使うと新しいプロセスセッションを開始でき、グループ kill が確実になります
    setsid python app/workers/mqtt_worker.py > "$LOG_DIR/mqtt.log" 2>&1 &
    echo $! > "$PID_MQTT" #PIDをファイルに保存
)
echo ""
echo "--MQTTワーカー起動完了--"
# FastAPIの起動
echo "--Fastapi サーバーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/BackEnd/"
    uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$LOG_DIR/fastapi.log" 2>&1 &
    echo $! > "$PID_FASTAPI" # PID をファイルに保存
)
echo ""
echo "--fastapiサーバー起動完了--"
echo "サーバーが起動するのを待機中"

sleep 5 # サーバー起動を待つために数秒待機

# Frontエンドの起動
echo "---フロントエンド起動---"
echo "npm確認中"

if [ ! -d "$FRONTEND_DATA" ] ; then
    read -p "$FRONTEND_DATAが見つかりませんでした。npm installを実行しますか[y/n]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ];then
        echo "npm install を実行中"
        (cd "$PROJECT_ROOT/frontend" && npm install)
        echo "npmは正常に実行されました"
    else
        echo "実行をキャンセルします"
        exit 1
    fi
else
    echo "npm確認完了確認できました"
fi

echo "--react開発サーバーをバックグラウンドで起動中--"
(
    cd "$PROJECT_ROOT/frontend"
    setsid npm run dev > "$LOG_DIR/react.log" 2>&1 & # setid を setsid に修正し、ログ出力先を変更
    echo $! > "$PID_REACT" # pidをファイルに保存
)

echo "起動完了"
echo "システムが稼働中です。ctrl+Cですべてを停止します"
echo ""

echo "フロントエンド: http://localhost:3000"
echo "FastAPIDocs: http://localhost:3000/docs"

# crl+C が押されたcleanup関数を呼び出す
trap 'cleanup' SIGINT
