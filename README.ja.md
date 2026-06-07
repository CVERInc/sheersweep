# sheersweep

[![CI](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml)

[English](./README.md) · **日本語** · [繁體中文](./README.zh-TW.md)

> **読める** Mac クリーナー。オープンソース・ドライラン優先・絶対に触れないリストを内蔵・すべてのアカウントを掃除。

たいていの Mac クリーナーはブラックボックスです。見えないところで何かを削除し、サブスクリプションを課し、マーケティングにはちょっとした恐怖をまぶしながら「信じてください」と言う。`sheersweep` はその逆です。**端から端まで読める短いシェルスクリプト 1 本**であり、**何かを解放する前に「何を解放するか」をすべて見せ**、**OS が自分で作り直すキャッシュ・一時ファイル・ログだけ**を消し、**絶対に触れないものを書き込みで固定**しています。

正直なクリーナー。サブスクなし、脅し文句なし、不意打ちなし。

## なぜ信頼できるか

- **全行を読める。** 約 150 行の `bash` です。危険な動詞（`find … -delete`）は 1 つのヘルパー内、下記のパスにのみ現れます。
- **まずドライラン。** `sheersweep --dry-run` は各項目が *どれだけ* 解放するかを表示し、何も削除しません。実行して、読んで、それから決める。
- **🔴 絶対に触れないリスト — どの行も到達しません:**
  写真 / 書類 / デスクトップ / ムービー / ミュージック、Clip Studio (CELSYS)、アプリの Containers と Application Support（アンインストール済みの Adobe を除く）、Dropbox / クラウド同期フォルダ、画面収録、メール / メッセージ / キーチェーン、あらゆる git リポジトリ、あらゆる Obsidian vault。
- **再生成されるゴミだけ。** 消すのはすべてキャッシュ・ログ・一時ファイルで、OS とアプリが次回起動時に作り直します。

## 何をするか

- `/Users` 配下の **すべてのアカウント**（現在も将来も）に対して:
  `Library/Caches`、`Library/Logs`、`~/.cache`、`~/.npm`、Xcode `DerivedData` / `DeviceSupport`、CoreSimulator キャッシュ、Cargo/Gradle キャッシュ、残った Adobe キャッシュ/サポート。
- システム全体（一度）： `/Library/Caches`、`/.adobeTemp`、`brew cleanup`。
- **ローカル APFS（Time Machine）スナップショットを解放** — ほとんどのクリーナーが飛ばし、ほとんどのユーザーが知らない手順です。スナップショットが容量を固定していると、ファイルを削除しても容量は戻りません。sheersweep はそれを解放し、しかも教えてくれます。

**すべてのアカウント**を 1 回で掃除します。他のツールが実行ユーザーしか掃除しない共有 Mac や家族の Mac で便利です。

## インストールと使い方

```bash
git clone https://github.com/CVERInc/sheersweep.git
cd sheersweep

./sheersweep --dry-run   # プレビュー — 何も削除しません（最初の実行に推奨）
./sheersweep             # 本番実行（全アカウント掃除のため sudo を一度求めます）
./sheersweep --version
./sheersweep --help
```

ダブルクリック派なら、デスクトップにコピーして `sheersweep.command` にリネーム、または `PATH` にシンボリックリンク:

```bash
ln -s "$PWD/sheersweep" /usr/local/bin/sheersweep
```

すべてのアカウントの掃除には管理者権限が必要なため、sheersweep は自身を `sudo` で再実行します（パスワードは一度）。`--version` / `--help` には不要です。

## 言語

UI は **English (en-US)・日本語 (ja-JP)・繁體中文 (zh-TW)** に対応し、システムのロケールから自動判定します（繁体字のみ。簡体字は英語にフォールバック）。強制するには:

```bash
SHEERSWEEP_LANG=ja-JP ./sheersweep --dry-run
```

## あえて狭く

sheersweep は **安全で再生成される** ものだけを消します。アプリのデータを漁る「アグレッシブ」「ディープ」クリーナーには成長させません — そこはクリーナーが「残したかったもの」を消してしまう場所であり、このツールが立つ信頼の対極です。狭く正直なほうが、広く怖いより良い。

## 動作環境

macOS（`tmutil`、APFS、標準の `/Users` 構成を使用）。純粋な `bash` ＋ システム標準ツールのみ — インストールする依存はありません。

## ライセンス

MIT © [CVER Inc.](https://cver.net) — *making delightful digital tools since 2011.*
