set -e

# 仮想環境設定
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
BACKEND_DIR="$PROJECT_ROOT/BackEnd"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
FRONTEND_DATA="$FRONTEND_DIR/node_modules"
ENV_PATH="$PROJECT_ROOT/.env"
EXAMPLE_ENV_PATH="$PROJECT_ROOT/.env.example"
VENV_NAME="Elevetor"
ACTIVATE_VENV="$PROJECT_ROOT/$VENV_NAME/bin/activate"
REQUIREMENTS="$BACKEND_DIR/requirements.txt"

LOG_DIR="$PROJECT_ROOT/logs" # ログファイル用のディレクトリを定義
PID_DIR="$PROJECT_ROOT/run" # PIDファイル用のディレクトリを定義
AUTO_YES=false
TEST_MODE=false

# 実行中のプロセスを追跡するためのPIDファイルを各のするディレクトリ
PID_MQTT="$PID_DIR/mqtt_worker.pid"
PID_MQTTPUB="$PID_DIR/testsendmqtt.pid"
PID_FASTAPI="$PID_DIR/fastapi_server.pid"
PID_REACT="$PID_DIR/react_dev.pid"
OS_RELEASE="/etc/os-release"
DEBUG_MODE=true
# logを出すための関数(かっこいいから)
log() {
    
    # ログ出力用の関数
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "[LOG] $(date +'%H:%M:%S') - $1"
    fi
    # DEBUG_MODE=false    
}
# スクリプト終了時にすべてのバックグラウンドプロセスを終了させる関数
cleanup(){
    log "システムをシャットダウン中"
    set +e
    PIDS=("$PID_MQTT" "$PID_MQTTPUB" "$PID_FASTAPI" "$PID_REACT")
    # 安全な終了処理の関数
    for pid_file in "${PIDS[@]}"; do
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if [ -n "$pid" ]; then
                # プロセスグループが存在するか確認してからkillを送るわ
                kill -TERM -- -"$pid" 2>/dev/null || true
            fi
            
            # PIDファイルを削除
            rm -f "$pid_file"
        fi
    done
    log "すべてのプロセスが停止しました"
}

backend() {
    log "バックエンドを起動"
    #仮想環境を有効化
    . $ACTIVATE_VENV
    sleep 2
    log "仮想環境を有効化完了"
    sleep 1
    # MQTTワーカーを起動
    log "MQTTワーカーをバックグラウンドで起動中"
    (
        cd "$BACKEND_DIR"
        # setsid を使うと新しいプロセスセッションを開始でき、グループ kill が確実になります
        setsid python -u -m app.workers.mqtt_worker > "$LOG_DIR/mqtt_worker.log" 2>&1 &
        echo $! > "$PID_MQTT" #PIDをファイルに保存
    )
    sleep 2
    log "MQTTワーカー起動完了"

    # testsendを有効化
    if [ "$TEST_MODE" = true ]; then
        (
            cd "$BACKEND_DIR"
            setsid python -u -m app.workers.testsendmqtt > "$LOG_DIR/testsendmqtt.log" 2>&1 &
            echo $! > "$PID_MQTTPUB" #PIDをファイルに保存
        )
        sleep 1
        log "テスト用MQTTパブリッシャー起動完了"
    fi

    # FastAPIの起動
    sleep 1
    log "Fastapi サーバーをバックグラウンドで起動中"
    (
        cd "$BACKEND_DIR"
        setsid uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$LOG_DIR/fastapi.log" 2>&1 &
        echo $! > "$PID_FASTAPI" # PID をファイルに保存
    )
    sleep 3
    log "fastapiサーバー起動完了"

}

frontend() {
    log "フロントエンドを起動"
    log "react開発サーバーをバックグラウンドで起動中"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log 外部IP: $LOCAL_IP
    (
        cd "$FRONTEND_DIR"
        sed -i "s|REACT_APP_BACKEND_URL=.*|REACT_APP_BACKEND_URL=http:\/\/${LOCAL_IP}:8000|" "$ENV_PATH"
        setsid npm run dev > "$LOG_DIR/react.log" 2>&1 & # setid を setsid に修正し、ログ出力先を変更
        echo $! > "$PID_REACT" # pidをファイルに保存
    )
    sleep 2 # React開発サーバーの初期化を待機
    echo ""
    awk 'NR>=2,NR<=10' "$LOG_DIR/react.log" || true # URLを表示
    echo ""
    log "起動完了"
    log "システムが稼働中です。ctrl+Cですべてを停止します"
}
# -y オプションがあるとき
while getopts "ty" opt; do
    case $opt in
        y) 
            AUTO_YES=true 
            log "すべての確認プロンプトに自動的に 'yes' と答えます"
        ;;
        t) 
            TEST_MODE=true
            log "テストモードが有効になりました。テスト用MQTTパブリッシャーが起動します"
        ;;
    esac
done

mkdir -p "$PID_DIR" # PIDファイル用のディレクトリを作成
mkdir -p "$LOG_DIR" # ログディレクトリを作成

# crl+C が押されたcleanup関数を呼び出す
trap cleanup EXIT

# バックエンドとフロントエンドを起動
backend
frontend

# コンソール表示用
# tail -f "$LOG_DIR/fastapi.log" -f "$LOG_DIR/mqtt.log" -f "$LOG_DIR/react.log" -f "$LOG_DIR/testsendmqtt.log"
# tail -f "$LOG_DIR/fastapi.log"

# 無限ループでスクリプトを実行し続ける
while true; do
    sleep 1;
done
# wait