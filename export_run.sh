set -e
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
TODAY=$(date +"%Y%m%d")
ENV_PATH="$PROJECT_ROOT/BackEnd/.env"
OUTPUT_PATH="$PROJECT_ROOT/export_data/elevator_data_export_$TODAY.csv"
SQL_FILE="$PROJECT_ROOT/BackEnd/app/database/export.sql"

# 環境変数の読み込み
if [ -f "$ENV_PATH" ]; then
     export $(grep -v '^#' $ENV_PATH | xargs)
else
    echo ".envファイルが見つかりませんでした"
    exit 1
fi
if [ ! -d "$PROJECT_ROOT/export_data" ]; then
    mkdir -p "$PROJECT_ROOT/export_data"
fi

echo "ファイルをエクスポート中"
mysql -u "$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" "$DB_NAME" --batch < "$SQL_FILE" > "$OUTPUT_PATH"

if [ $? -eq 0 ]; then
    echo "データベースをエクスポートしました: $OUTPUT_PATH"
    exit 0
else
    echo "データベースのエクスポートに失敗しました"
    exit 1
fi
echo "終了します"
exit 0