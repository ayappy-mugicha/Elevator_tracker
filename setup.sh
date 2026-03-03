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
SQL_TEMPLATE="$BACKEND_DIR/app/database/create_tables.sql"
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
    set -a
    source "$ENV_PATH"
    set +a

    # データベースの接続確認
    log "データベースを確認中"
    # その後、既存のデータベース接続確認へ進む
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
            log "データベースを作成中 $DB_NAME"
            # "$PROJECT_ROOT/$VENV_NAME/bin/python" "$BACKEND_DIR/app/database/create_tables.py"
            sed -e"s/__DB_NAME__/$DB_NAME/g" \
            -e"s/__TABLE_NAME__/$DB_TABLE/g" \
            "$SQL_TEMPLATE" | mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD"
            sleep 1
            
            sudo systemctl enable mariadb || sudo systemctl enable mysql
            sudo systemctl start mariadb || sudo systemctl start mysql

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

    log "NGINXに書き込み中"
    envsubst '${NGINX_PORT} ${LOCAL_HOST} ${VITE_PORT} ${BACKEND_PORT}' < $NGINX_TEMP > $NGINX_PATH
    cd $PROJECT_ROOT
    sudo mv "$NGINX_PATH" "$NGINX_DIR/$NGINX_PATH"
    sudo ln -sf "$NGINX_DIR/$NGINX_PATH" "$NGINX_ENABLE/"
    
    if [ ! -f "$NGINX_DIR/$NGINX_PATH" ]; then
        log "正常に書き込みができませんでしたnginx.conf.templateが存在してるか確認してください"
        exit 1
    fi

    # defaultファイルを削除しないと作ったconfが動かないため消す。他に方法あったりするのかな。
    if [ -f "$NGINX_ENABLE/default" ]; then
        sudo rm -rf "$NGINX_ENABLE/default"
    fi
    log "正常に書き込みができました"

    if sudo nginx -t; then
        log "設定を反映中"
        sudo systemctl start nginx
        sudo systemctl reload nginx
        log "反映完了"
    else
        log "何らかのエラーがあります確認してください"
        exit 1
    fi
    
    log "ポートを確認中"
    sudo ufw allow from $LOCAL_HOST

    for port in $SSH_PORT $NGINX_PORT; do
        if ! sudo ufw status | grep -q "$port/tcp"; then
            log "ポート $port を許可リストに追加中..."
            sudo ufw allow "$port/tcp"
        fi
    done
    sudo ufw enable
    sudo ufw reload
    log "ポート確認完了"
}
# 依存関係をインストールする関数
install_dependencies() {
    log "依存関係の確認中"
    
    # OS_COMMANDSに raspbian を追加
    declare -A OS_COMMANDS=(
        [debian]="apt" [ubuntu]="apt" [raspbian]="apt" [fedora]="dnf" [arch]="pacman"
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

    log "パッケージリストを更新中..."
    sudo $CMD update -y

    # 1. Python の確認 (バージョン固定をやめ、標準の python3-venv を利用)
    if ! command -v python3 &> /dev/null; then
        log "Python3 をインストールします"
        sudo $CMD install -y python3 python3-pip python3-venv
    fi

    # 2. Node.js (ラズパイ対応版)
    if ! command -v node &> /dev/null; then
        log "Node.js をインストールします"
        if [[ "$OS_NAME" == "raspbian" || "$OS_NAME" == "debian" || "$OS_NAME" == "ubuntu" ]]; then
            # ラズパイOS/Debian系向けの標準的な導入
            sudo $CMD install -y nodejs npm
        fi
    fi

    # 3. MySQL/MariaDB (ラズパイは MariaDB が標準)
    if ! command -v mysql &> /dev/null; then
        log "Database Server をインストールします"
        if [[ "$OS_NAME" == "ubuntu" ]]; then
            sudo $CMD install -y mysql-server
        else
            sudo $CMD install -y mariadb-server
        fi
    fi

    # 4. Nginx と ufw
    for pkg in nginx ufw envsubst; do
        if ! command -v $pkg &> /dev/null; then
            # envsubst は gettext パッケージに含まれる
            [[ "$pkg" == "envsubst" ]] && pkg="gettext"
            log "$pkg をインストール中"
            sudo $CMD install -y $pkg
        fi
    done

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