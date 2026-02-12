set -e

# 仮想環境設定
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
BACKEND_DIR="$PROJECT_ROOT/BackEnd"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
FRONTEND_DATA="$FRONTEND_DIR/node_modules"
FRONT_ENV_PATH="$FRONTEND_DIR/.env"
BACKEND_ENV_PATH="$BACKEND_DIR/.env"
VENV_NAME="Elevetor"
ACTIVATE_VENV="$PROJECT_ROOT/$VENV_NAME/bin/activate"
REQUIREMENTS="$BACKEND_DIR/requirements.txt"

LOG_DIR="$PROJECT_ROOT/logs" # ログファイル用のディレクトリを定義
PID_DIR="$PROJECT_ROOT/run" # PIDファイル用のディレクトリを定義
mkdir -p "$PID_DIR" # PIDファイル用のディレクトリを作成
mkdir -p "$LOG_DIR" # ログディレクトリを作成
AUTO_YES=false
TEST_MODE=false

# 実行中のプロセスを追跡するためのPIDファイルを各のするディレクトリ
PID_MQTT="$PID_DIR/mqtt_worker.pid"
PID_MQTTPUB="$PID_DIR/testsendmqtt.pid"
PID_FASTAPI="$PID_DIR/fastapi_server.pid"
PID_REACT="$PID_DIR/react_dev.pid"
DEBUG_MODE=true
# logを出すための関数(かっこいいから)
log() {
    
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
            sleep 1
        else
            log "了解です。終了します"
            exit 1
        fi
    fi
    log "仮想環境の確認完了"
    log .envファイルの確認中
    
    if [ ! -f "$BACKEND_ENV_PATH" ]; then
        log "バックエンドの.envファイルとフロントエンドの.envファイルが見つかりません:"
        log ".env.exampleをコピーして.envファイルを作成しますか"
        if [ "$AUTO_YES" = true ]; then
            answer="y"
        else
            read -p ".envファイルを作成しますか [y/n]: " answer
        fi
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            cp "$BACKEND_DIR/.env.example" "$BACKEND_ENV_PATH"
            cp "$FRONTEND_DIR/.env.example" "$FRONT_ENV_PATH"
            
            read -p "DB_USERを設定してください: " db_user
            sed -i "s/DB_USER=.*/DB_USER=${db_user}/" "$BACKEND_ENV_PATH"

            read -p "DB_PASSWORDを設定してください: " db_password
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${db_password}/" "$BACKEND_ENV_PATH"
            
            read -p "DB_NAMEを設定してください: " db_name
            sed -i "s/DB_NAME=.*/DB_NAME=${db_name}/" "$BACKEND_ENV_PATH"
            
            log ".envファイルを作成しました"
            sleep 1
        else
            log "了解です。終了します"
            exit 1
        fi
    fi

    # データベースの接続確認
    log "データベースを確認中"
    export $(grep -v '^#' $BACKEND_ENV_PATH | xargs)
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
            python "$BACKEND_DIR/app/database/create_tables.py"
            sleep 1
            log "データベースを作成しました"
        else
            log "了解です。終了します"
            exit 1
        fi
    fi
    log "データベースの確認完了"
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
            (cd "$FRONTEND_DIR" && npm install)
            sleep 1
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
# 依存関係をインストールする関数
install_dependenceis() {
    # OSの種類を判別して依存関係をインストールする関数

    declare -A OS_COMMANDS
    OS_COMMANDS=(
        [debian]="apt"
        [ubuntu]="apt"
        [fedora]="dnf"
        [arch]="pacman"
        [opensuse]="zypper"
        [centos]="dnf"
        [rhel]="dnf"
        [amzn]="dnf"
    )

    local REQUIRED_CMDS=("python3" "npm" "mysql")
    log "依存関係の確認中"
    OS_NAME=""
    PYTHON_EXE=true
    NPM_EXE=true
    MYSQL_EXE=true
    
    # OS情報を取得
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        log "OS検出: $OS_NAME"
    fi
    
    # OSの種類に応じてコマンドを選択
    CMD=${OS_COMMANDS[$OS_NAME]}
    log "パッケージマネージャー: $CMD"
    if [ -z "$CMD" ]; then
        log "対応していないOSです: $OS_NAME"
        exit 1
    fi

    # コマンドの存在を確認
    if ! command -v python3 &> /dev/null; then
        PYTHON_EXE=false
    fi
    if ! command -v npm &> /dev/null; then
        NPM_EXE=false
    fi
    if ! command -v mysql &> /dev/null; then
        MYSQL_EXE=false
    fi
    
    
    if [ "$PYTHON_EXE" = true ] && [ "$NPM_EXE" = true ] && [ "$MYSQL_EXE" = true ]; then
        log "すべての依存関係がインストールされています。"
        return
    fi

    log "依存関係が不足しています。インストールを開始します。"
    sudo $CMD update

    for tool in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log "依存関係 '$tool' が見つかりません。インストールします。"
            sudo $CMD install -y "$tool"
            sleep 1
            log "依存関係 '$tool' のインストールが完了しました。"
        else
            log "依存関係 '$tool' はすでにインストールされています。"
        fi
    done
    log "環境確認完了"
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
        sed -i "s|REACT_APP_BACKEND_URL=.*|REACT_APP_BACKEND_URL=http:\/\/${LOCAL_IP}:8000|" "$FRONT_ENV_PATH"
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

# crl+C が押されたcleanup関数を呼び出す
trap cleanup EXIT

# 環境を確認
install_dependenceis
check_environment

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