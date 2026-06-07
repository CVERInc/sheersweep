# sheersweep

[![CI](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml)

[English](./README.md) · [日本語](./README.ja.md) · **繁體中文**

> **你讀得懂的** Mac 清理工具。開源、先預演（dry-run）、內建「絕不碰」清單、一次掃所有帳號。

多數 Mac 清理軟體是個黑箱：它在你看不見的地方刪東西、收訂閱、行銷裡還摻一點恐嚇，然後要你「相信它」。`sheersweep` 正好相反——它是**一支你能從頭讀到尾的短 shell 腳本**，**在動手清理之前就把「會清掉什麼」全部攤給你看**，**只清作業系統與 app 會自動重建的快取、暫存、log**，而且**用寫死的清單固定住「絕不碰」的東西**。

誠實的清理工具。不收訂閱、不恐嚇、不給你意外。

## 為什麼能信任它

- **你讀得懂每一行。** 全部約 150 行 `bash`。危險的動詞（`find … -delete`）只出現在一個 helper 裡、只作用在下面列出的路徑上。
- **先預演。** `sheersweep --dry-run` 會印出每一項 *會* 釋放多少，但不刪任何東西。跑一次、讀過、再決定。
- **🔴 絕不碰清單——腳本沒有任何一行碰得到：**
  照片 / 文件 / 桌面 / 影片 / 音樂、Clip Studio (CELSYS)、app 的 Containers 與 Application Support（已卸載的 Adobe 除外）、Dropbox / 雲端同步資料夾、螢幕錄影、Mail / Messages / 鑰匙圈、任何 git repo、任何 Obsidian vault。
- **只清會重建的垃圾。** 它清掉的全是快取、log 或暫存，作業系統與你的 app 下次用到時會自己重建。

## 它做什麼

- 對 `/Users` 底下的 **每一個帳號**（現有與未來）：
  `Library/Caches`、`Library/Logs`、`~/.cache`、`~/.npm`、Xcode `DerivedData` / `DeviceSupport`、CoreSimulator 快取、Cargo/Gradle 快取、殘留的 Adobe 快取/支援檔。
- 系統層（一次）：`/Library/Caches`、`/.adobeTemp`、`brew cleanup`。
- **釋放本機 APFS（Time Machine）快照**——這是多數清理軟體略過、多數使用者沒聽過的一步：只要快照還釘住已刪的資料，刪檔案也不會把空間還給你。sheersweep 會把它釋放出來，而且會告訴你。

它**一次掃所有帳號**——在共用或家庭 Mac 上特別好用，因為其他工具多半只清「正在執行的那個使用者」。

## 安裝與使用

```bash
git clone https://github.com/CVERInc/sheersweep.git
cd sheersweep

./sheersweep --dry-run   # 預覽——不刪任何東西（建議第一次這樣跑）
./sheersweep             # 正式清理（為了掃所有帳號，會問一次 sudo 密碼）
./sheersweep --version
./sheersweep --help
```

想雙擊執行？複製到桌面、改名成 `sheersweep.command`，或建一個 symlink 到 `PATH`：

```bash
ln -s "$PWD/sheersweep" /usr/local/bin/sheersweep
```

掃所有帳號需要管理員權限，所以 sheersweep 會以 `sudo` 重新執行自己（只問一次密碼）。`--version` / `--help` 不需要。

## 語言

介面支援 **English (en-US)、日本語 (ja-JP)、繁體中文 (zh-TW)**，依系統 locale 自動判定（只支援繁體；簡體會 fallback 到英文）。要強制指定：

```bash
SHEERSWEEP_LANG=zh-TW ./sheersweep --dry-run
```

## 刻意做得窄

sheersweep 刻意只清**安全、會自動重建**的東西。它不會長出那種翻遍 app 資料的「積極」「深度」清理——那正是清理軟體會誤刪你想留的東西的地方，也跟這支工具立足的信任完全相反。**窄而誠實，勝過廣而嚇人。**

## 系統需求

macOS（用到 `tmutil`、APFS、標準的 `/Users` 結構）。純 `bash` ＋ 系統內建工具——沒有任何要安裝的相依套件。

## 授權

MIT © [CVER Inc.](https://cver.net) — *making delightful digital tools since 2011.*
