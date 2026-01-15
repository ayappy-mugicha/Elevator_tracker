# Elevetor_tracker_website

## 使い方
*run.shを実行してください。そうすれば動くはず

## 開発者が学んだこと
これでpythonの一つ前のディレクトリのファイルを参照できる
``` python
import os
import sys
# 1. 自分のいる場所（appフォルダ）の絶対パスを取得
current_dir = os.path.dirname(os.path.abspath(__file__))
# 2. 一つ上の階層（親フォルダ）のパスを作る
parent_dir = os.path.dirname(current_dir)
# 3. Pythonの「探し物リスト」に親フォルダを追加！
sys.path.append(parent_dir)
```
* bashファイルで以下のことをすると解放しやすいらしい。
```bash
    # setsid を使うと新しいプロセスセッションを開始でき、グループ kill が確実になります
    setsid python app/workers/mqtt_worker.py > /dev/null 2>&1 &
```
## 導入したい技術スタック
<ul>
    <li><b>SORACOM (SORACOM Beam/Canal)</b>：
日本のIoTで超定番！SIMカードと一緒に使うと、セキュリティ設定を肩代わりしてくれるから、デバイス側の負担が減ってすごく楽ちんだよ。
    <li><b>AWS IoT Core / Azure IoT Hub</b>：
世界中で使われている超巨大な郵便局。将来的にデバイスが何万台に増えても大丈夫な、とっても頼れるサービスだよ。
    <li><b>HiveMQ Cloud / Shiftr.io</b>：
「まずは手軽に試したい！」という時にぴったりな、設定が簡単なクラウド型ブローカーだよ。
</ul>