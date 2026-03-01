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
RUN="$PROJECT_ROOT/run.sh"

NGINX_DIR="/etc/nginx/sites-available"
NGINX_ENABLE="/etc/nginx/sites-enabled"
NGINX_PATH="$VENV_NAME-project.conf"
NGINX_TEMP="nginx.conf.template"
AUTO_YES=false

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
export $(grep -v '^#' $ENV_PATH | xargs)

check_environment(){
    log "仮想環境の確認中"
    if [ ! -f "$ACTIVATE_VENV" ]; then
        log "仮想環境が見つかりません: $ACTIVATE_VENV"
        [[ "$AUTO_YES" != true ]] && read -p "仮想環境を構築しますか [y/n]: " answer|| answer="y"

        echo ""
        if [[ "$answer" =~ ^[Yy]$ ]]; then

            log "仮想環境を構築します"
            python3 -m venv "$VENV_NAME"
            
            log "仮想環境の有効化をしました。続いてモジュールをインポートします"
            "$VENV_NAME/bin/pip" install --upgrade pip
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
    
    if [ ! -f "$ENV_PATH" ]; then
        log "バックエンドの.envファイルとフロントエンドの.envファイルが見つかりません:"
        log ".env.exampleをコピーして.envファイルを作成しますか"
        [[ "$AUTO_YES" != true ]] && read -p ".envファイルを作成しますか [y/n]: " answer || answer="y"
        echo ""
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log ".envファイルを作成中"
            cp "$EXAMPLE_ENV_PATH" "$ENV_PATH"
            # 入力関数（空入力を防ぐ）
            ask_and_set() {
                local prompt=$1
                local key=$2
                local val=""
                while [ -z "$val" ]; do
                    read -p "$prompt: " val
                done
                # スラッシュが含まれても大丈夫なように | をデリミタに使用
                sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_PATH"
            }
            ask_and_set "DB_USERを設定してください" "DB_USER"
            ask_and_set "DB_PASSWORDを設定してください" "DB_PASSWORD"
            ask_and_set "DB_NAMEを設定してください" "DB_NAME"
            
            log ".envファイルを作成しました"
            sleep 1
        else
            log "了解です。終了します"
            exit 1
        fi
    fi

    # データベースの接続確認
    log "データベースを確認中"
    # その後、既存のデータベース接続確認へ進む
    log "データベースを確認中"
    if mysql -u "$DB_USER" -p"${DB_PASSWORD}" -h "$DB_HOST" -e "USE $DB_NAME" >/dev/null 2>&1; then
        log "データベース '$DB_NAME' を確認できました。"
    else
        log "エラー: データベース '$DB_NAME' を確認できません。"

        [[ "$AUTO_YES" = true ]] && read -p "データベースを作成しますか?[y/n]: " answer || answer="y"
        echo ""

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log "MySQLユーザー '${DB_USER}' が存在しないか、接続できません。ユーザーを作成します..."
            sudo mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
            sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost';"
            sudo mysql -u root -e "FLUSH PRIVILEGES;"
            log "MySQLユーザーの設定が完了しました。再度接続を確認します..."
            log "データベースを作成中"
            "$PROJECT_ROOT/$VENV_NAME/bin/python" "$BACKEND_DIR/app/database/create_tables.py"
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
        [[ "$AUTO_YES" = true ]] && read -p "$FRONTEND_DATA が見つかりませんでした。npm installを実行しますか[y/n]: " answer || answer="y"
        echo ""

        if [[ "$answer" =~ ^[Yy]$ ]];then
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
install_dependencies() {
    log "依存関係の確認中"
    
    declare -A OS_COMMANDS=(
        [debian]="apt" [ubuntu]="apt" [fedora]="dnf" [arch]="pacman"
        [opensuse]="zypper" [centos]="dnf" [rhel]="dnf" [amzn]="dnf"
    )

    if [ -f "/etc/os-release" ]; then
        . "/etc/os-release"
        OS_NAME=$ID
        log "OS検出: $OS_NAME"
    else 
        log "OS情報を取得できません"; exit 1
    fi

    CMD=${OS_COMMANDS[$OS_NAME]}
    if [ -z "$CMD" ]; then
        log "対応していないOSです: $OS_NAME"; exit 1
    fi
    sudo $CMD update -y
    sudo $CMD upgrade -y

    # 1. Python の確認とインストール
    if ! command -v python3 &> /dev/null; then
        log "Python3 をインストールします"
        
        sudo $CMD install -y python3 python3-venv python3-pip
    fi
    # 2. Node.js の確認とインストール
    if ! command -v nodejs &> /dev/null; then
        log "Node.js をインストールします"
        sudo $CMD install -y nodejs npm
    fi

    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then

        if ! python3 -m venv --help &> /dev/null; then
            log "python3-venv をインストールします"
            # Ubuntu 24.04 等で必要な python3.12-venv を含め、幅広く試行
            sudo $CMD install -y python3.12-venv # || sudo $CMD install -y python3.12-venv
            PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
            log "検出されたPythonバージョン: $PY_VER"
            
            # python3.12-venv などの具体的なパッケージ名を指定してインストール
            sudo $CMD update -y
            sudo $CMD install -y "python${PY_VER}-venv" || sudo $CMD install -y python3-venv
            
        fi
        # 2. MySQL の確認とインストール (コマンド名は mysql)
        if ! command -v mysql &> /dev/null; then
            log "MySQL をインストールします"
            sudo $CMD install -y mysql-server
        fi
        # 3. Node.js の確認とインストール
        if ! command -v node &> /dev/null || [[ $(node -v | cut -d'.' -f1 | sed 's/v//') -lt 20 ]]; then
            log "Node.js 20系をインストールまたはアップグレードします"
            # NodeSource を使用して 20.x を導入
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo $CMD install -y nodejs
        fi
        # ファイアウォールの設定 (ufw)
        # Nginx の設定後でやっておいて。
        if ! command -v ufw &> /dev/null; then
            log "ufwをインストール中"
            sudo $CMD install -y ufw
        fi

        log "NGINXの設定ファイルを作成中"
        if ! command -v nginx &> /dev/null; then
            log "nginxをインストールします"
            sudo $CMD install -y nginx
        fi
        
        envsubst '${NGINX_PORT} ${LOCAL_HOST} ${VITE_PORT} ${BACKEND_PORT}' < $NGINX_TEMP > $NGINX_PATH
        cd $PROJECT_ROOT
        sudo mv "$NGINX_PATH" "$NGINX_DIR/$NGINX_PATH"
        sudo ln -sf "$NGINX_DIR/$NGINX_PATH" "$NGINX_ENABLE/"

        if sudo nginx -t; then
            log "設定を反映中"
            sudo systemctl start nginx
            sudo systemctl reload nginx
            log "反映完了"
        else
            log "何らかのエラーがあります確認してください"
            exit 1
        fi
        
        if ! sudo ufw status | grep -q "$SSH_PORT/tcp"; then
            log "opennig port ssh $SSH_PORT"
            sudo ufw allow $SSH_PORT/tcp
            # sudo ufw reload
        fi

        if ! sudo ufw status | grep -q "$NGINX_PORT/tcp"; then
            log "ポート $NGINX_PORT を許可リストに追加中..."
            sudo ufw allow $NGINX_PORT/tcp
            # sudo ufw reload
        fi
        sudo ufw enable
        sudo ufw reload

    
    else
        # 2. MariaDB の確認とインストール (コマンド名は mariadb または mysql)
        if ! command -v mariadb &> /dev/null; then
            log "MariaDB をインストールします"
            sudo $CMD install -y mariadb-server # RedHat系などはMariaDBが一般的
        fi
        # # 3. firewalld の確認とインストール
        # if ! command -v firewall-cmd &> /dev/null; then
        #     log "firewalldをインストール中"
        #     sudo $CMD install -y firewalld
        #     sudo systemctl start firewalld
        #     sudo systemctl enable firewalld
        # fi
        
        # # ファイアウォールの設定 (firewalld)
        # if sudo firewall-cmd --list-ports | grep -q "$VITE_PORT/tcp"; then
        #     log "ポート $VITE_PORT は許可済み"
        # else
        #     log "ポート $VITE_PORT を許可リストに追加中..."
        #     # sudo firewall-cmd --add-port=$VITE_PORT/tcp --permanent
        #     # sudo firewall-cmd --reload
        # fi
    fi
    log "依存関係の確認完了"
}
# -y オプションがあるとき
while getopts "y" opt; do
    case $opt in
        y) 
            AUTO_YES=true 
            log "すべての確認プロンプトに自動的に 'yes' と答えます"
        ;;
    esac
done

# 環境を確認
install_dependencies
check_environment
log "環境設定が完了しました"

log "このままrun.shを実行しますか?"
[[ "$AUTO_YES" != true ]] && read -p "続行しますか? [y/n]: " answer || answer="y"
echo ""
if [[ "$answer" =~ ^[Yy]$ ]]; then
    log "run.shを実行します"
    bash "$RUN"
else
    log "了解です。終了します"
    exit 1
fi