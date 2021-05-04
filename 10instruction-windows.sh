#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

if [ ! -r $CERTS_DIR/$CA_CERT ]; then
    echo "[ERROR] ルート認証局 証明書ファイル $CERTS_DIR/$CA_CERT が見つからないか、読み込めません。"
    echo "01create-certs.sh を実行して証明書を生成してください。"
    exit 1
fi

echo "==================== Windows 向けセットアップガイド ===================="
echo
echo "1. 次のテキストをメモ帳などのテキストエディタに貼り付けて、$CA_CERT という名前で適当な場所に保存してください。"
echo
echo "############## ここから"
echo
cat $CERTS_DIR/$CA_CERT
echo
echo "############## ここまで"
echo
echo "2. 保存した $CA_CERT を右クリックして「証明書のインストール」を選択し、"
echo "   「現在のユーザ」の「信頼されたルート証明機関」証明書ストアにインポートしてください。"
echo "   インポートの際、拇印(sha1) が次と一致することを確認してください。"
echo
openssl x509 -in $CERTS_DIR/$CA_CERT -noout -fingerprint
echo
echo "3. ブラウザを起動し(既に起動中のものがある場合は証明書を反映させるため再起動してください)、 "
echo "    https://$SRV_CN/ にアクセスできることを確認してください。"
echo
echo "   (DNS解決できない場合は shell:system\drivers\etc\hosts に記述したり、"
echo "    直接アクセスできない場合はプロキシやポートフォワーディングを設定するなどしてください)"
echo
echo "以上で完了です。"
