set -e

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
# 仮想環境設定
VENV_NAME="Elevetor"
REQUIREMENTS="$PROJECT_ROOT/BackEnd/requirements.txt"
LOG_DIR="$PROJECT_ROOT/logs" # ログファイル用のディレクトリを定義
FRONTEND_DATA="$PROJECT_ROOT/frontend/node_modules"
ACTIVATE_VENV="$PROJECT_ROOT/$VENV_NAME/bin/activate"

PID_DIR="$PROJECT_ROOT/run"
mkdir -p "$PID_DIR"
mkdir -p "$LOG_DIR" # ログディレクトリを作成
AUTO_YES=false

# 環境変数ファイルのパス
ENV_PATH="$PROJECT_ROOT/BackEnd/.env"

# 実行中のプロセスを追跡するためのPIDファイルを各のするディレクトリ
PID_MQTT="$PID_DIR/mqtt_worker.pid"
PID_MQTTPUB="$PID_DIR/testsendmqtt.pid"
PID_FASTAPI="$PID_DIR/fastapi_server.pid"
PID_REACT="$PID_DIR/react_dev.pid"

# logを出すための関数(かっこいいから)
log() {
    DEBUG_MODE=true
    # ログ出力用の関数
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "[LOG] $(date +'%H:%M:%S') - $1"
    fi
    DEBUG_MODE=false    
}
# スクリプト終了時にすべてのバックグラウンドプロセスを終了させる関数
cleanup(){
    log "システムをシャットダウン中"
    set +e
    # 安全な終了処理の関数
    safe_kill() {
        local pid_file=$1
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if [ -n "$pid" ]; then
                # プロセスグループが存在するか確認してからkillを送るわ
                kill -TERM -- -"$pid" 2>/dev/null || true
            fi
        fi
    }
    # PIDファイルを使ってプロセスグループごと終了
    safe_kill "$PID_MQTT"
    safe_kill "$PID_MQTTPUB"
    safe_kill "$PID_FASTAPI"
    safe_kill "$PID_REACT"

    # PIDファイルを削除
    rm -f "$PID_MQTT" "$PID_MQTTPUB" "$PID_FASTAPI" "$PID_REACT"
    # kill -0 0 2>/dev/null
    log "すべてのプロセスが停止しました"
}

check_environment(){
    log "仮想環境の確認中"
    
    if [ ! -f "$ACTIVATE_VENV" ]; then
        log "仮想環境が見つかりません: $ACTIVATE_VENV"
        if [ "$AUTO_YES" = true ]; then
            answer="y"
        else
            read -p "仮想環境を構築しますか [y/n]: " answer
        fi
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then

            log "仮想環境を構築します"
            python3 -m venv "$VENV_NAME"
            
            log "仮想環境の有効化をしました。続いてモジュールをインポートします"
            "$VENV_NAME/bin/pip" install -r "$REQUIREMENTS" # REQUIREMENTS変数を引用符で囲む
            log "モジュールをインポートできました"
        else
            log "了解です。終了します"
            exit 1
        fi
    fi
    log "仮想環境の確認完了"
    log "データベースを確認中"
    # データベースの接続確認
    if [ -f "$ENV_PATH" ]; then
        export $(grep -v '^#' $ENV_PATH | xargs)
        if mysql -u "$DB_USER" -p"${DB_PASSWORD}" -h "$DB_HOST" -e "USE $DB_NAME" >/dev/null 2>&1; then
            log "データベース '$DB_NAME' を確認できました。"
        else
            log "エラー: データベース '$DB_NAME' を確認できません。"
            if [ "$AUTO_YES" = true ]; then
                answer="y"
            else
                read -p "データベースを作成しますか?[y/n]: " answer
            fi
            echo ""
            if [[ "$answer" == "y" || "$answer" == "Y" ]]; then

                log "データベースを作成中"
                python "$PROJECT_ROOT/BackEnd/app/database/create_tables.py"
                log "データベースを作成しました"
            else
                log "了解です。終了します"
                exit 1
            fi
        fi
    else
        log "警告: .envファイルが見つからないため、データベース接続確認をスキップします: $ENV_PATH"
    fi
    log "npm確認中"

    if [ ! -d "$FRONTEND_DATA" ] ; then
        if [ "$AUTO_YES" = true ]; then
                answer="y"
        else
            read -p "$FRONTEND_DATA が見つかりませんでした。npm installを実行しますか[y/n]: " answer
        fi
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]];then
            log "npm install を実行中"
            (cd "$PROJECT_ROOT/frontend" && npm install)
            log "npmは正常に実行されました"
        else
            log "実行をキャンセルします"
            exit 1
        fi
    else
        log "npm確認完了確認できました"
    fi
    echo ""
}

# -y オプションがあるとき
while getopts "y" opt; do
    case $opt in
        y) AUTO_YES=true ;;
    esac
done
# crl+C が押されたcleanup関数を呼び出す
trap cleanup EXIT

# 環境を確認
check_environment
log "バックエンドを起動"

#仮想環境を有効化
. $ACTIVATE_VENV
log "仮想環境を有効化完了"
# echo ""

# MQTTワーカーを起動
log "MQTTワーカーをバックグラウンドで起動中"
(
    cd "$PROJECT_ROOT/BackEnd"
    # setsid を使うと新しいプロセスセッションを開始でき、グループ kill が確実になります
    setsid python -m app.workers.mqtt_worker > "$LOG_DIR/mqtt_worker.log" 2>&1 &
    echo $! > "$PID_MQTT" #PIDをファイルに保存
)
log "MQTTワーカー起動完了"
# sleep 2 # MQTTワーカーの初期化を待機

# testsendを有効化
if [ "$AUTO_YES" = true ]; then

    log "テスト用MQTTパブリッシャー起動完了"
    (
        cd "$PROJECT_ROOT/BackEnd"
        setsid python -u -m app.workers.testsendmqtt > "$LOG_DIR/testsendmqtt.log" 2>&1 &
        echo $! > "$PID_MQTTPUB" #PIDをファイルに保存
    )
    # sleep 2 # MQTTパブリッシャーの初期化を待機
fi

# FastAPIの起動
log "Fastapi サーバーをバックグラウンドで起動中"
(
    cd "$PROJECT_ROOT/BackEnd/"
    setsid uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$LOG_DIR/fastapi.log" 2>&1 &
    echo $! > "$PID_FASTAPI" # PID をファイルに保存
)
log "fastapiサーバー起動完了"
log "サーバーが起動するのを待機中"

# sleep 2 # サーバー起動を待つために数秒待機

# Frontエンドの起動
echo ""
log "フロントエンド起動"
log "react開発サーバーをバックグラウンドで起動中"
(
    cd "$PROJECT_ROOT/frontend"
    setsid npm run dev > "$LOG_DIR/react.log" 2>&1 & # setid を setsid に修正し、ログ出力先を変更
    echo $! > "$PID_REACT" # pidをファイルに保存
)
sleep 1 # React開発サーバーの初期化を待機
echo ""
awk 'FNR==2,NFR==10' "$LOG_DIR/react.log" || true # URLを表示
echo ""
log "起動完了"
log "システムが稼働中です。ctrl+Cですべてを停止します"

# コンソール表示用
# tail -f "$LOG_DIR/fastapi.log" -f "$LOG_DIR/mqtt.log" -f "$LOG_DIR/react.log" -f "$LOG_DIR/testsendmqtt.log"

# 無限ループでスクリプトを実行し続ける
while true; do
    sleep 1;
done