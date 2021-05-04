Docker Hub local mirror setup helper scripts
============================================

## Overview / 概要

Docker Hub の Pull request limit が厳しくなった関係で、制限を緩和するためにローカルでキャッシュするレジストリが欲しいなというのがきっかけです。

このスクリプト群は、Sonatype Nexus Repository Manager (以下NXRM) を利用し、ローカル環境に Docker Hub レジストリのイメージをキャッシュするミラーを作成します。
下記の処理を自動化します。
* ローカル認証局とTLS(SSL)サーバ証明書の生成
* Docker と NXRM のインストールとリポジトリ設定
* Nginx のインストールとHTTPS(TLS)リバースプロキシ設定
* クライアントの Docker デーモン設定の生成

----

## How to use / 使い方

1. 適当な場所にこのリポジトリをクローンします
2. config ファイルを自分好みに設定します
3. 01 ~ 03 のスクリプトを順番に実行します
4. クライアントマシンの設定方法については、Windows 向けには 10instruction-windows.sh を、Linux 向けには 11instruction-linux.sh を実行して表示される内容に従ってください。

----

## System requirements / 動作環境
* OS
  * Ubuntu 18.04 (bionic), 20.04 (focal) で動作確認しています
  * Red Hat 系 (CentOSなど) では証明書インストールパスやコマンドが異なるため動作しません
* CPU, Memory
  * NXRM の要件に従います: https://help.sonatype.com/repomanager3/installation/system-requirements
* Storage
  * イメージを蓄える性質上、最低でも数百GB必要です
* Network
  * インターネットにダイレクト接続できる環境が必要です
  * プロキシには現状対応していません。そのうち対応予定
    * プロキシ部分だけ自分で設定すればいけると思います
* Software
  * スクリプト内で curl, gzip, base64, openssl, sudo, awk を使用しているため、事前にインストールが必要です (といってもほぼデフォルトでインストールされていると思います)
  * スクリプトの実行で docker, jq, nginx がシステムにインストールされます

----

## License / ライセンス
MIT License に基づきます。

ライセンス条項にある通り、本スクリプトは無保証です。実行によって生じた如何なる損害やスクリプトの不具合について作者は一切の責を負いません。

---

## Author
@zeroichi
