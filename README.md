# agent-support

リポジトリの **AGENTS.md / `.agents/skills`** と **Claude Code の `CLAUDE.md` / `.claude/skills`** を相対 symbolic link で共通化する Swift 製 CLI。

片方を編集すれば両エコシステムに即反映されるため、設定の二重管理から解放されます。

## なぜ必要か

AI エージェント向け設定ファイルは、AGENTS.md 系（共通仕様）と CLAUDE.md（Claude Code）で同じ内容を持つことが多く、手動で同期するとずれや上書き事故が発生しがちです。`agent-support sync` を1度叩けば、リポジトリの初期状態がどうであれ次の4不変条件を満たした状態に正規化されます。

1. `AGENTS.md` が実体ファイルとして存在する
2. `CLAUDE.md` が `AGENTS.md` への **相対** symlink である
3. `.agents/skills/` ディレクトリが存在する（空のときのみ `.gitkeep` を配置）
4. `.claude/skills` が `../.agents/skills` への **相対** symlink である

冪等なので何度実行しても安全です。

## インストール

### Homebrew は未提供。`make install` を使用

```bash
git clone git@github.com:susieyy/agent-support.git
cd agent-support
make install              # /usr/local/bin/agent-support (要 sudo の環境あり)

# またはユーザーローカルに導入
PREFIX=$HOME/.local make install
# $HOME/.local/bin を PATH に含める
```

### 必要環境

- macOS 13 以降
- Swift 5.9 以降（Xcode 15+ または `swift` コマンド）

## 使い方

```bash
cd <対象リポジトリ>
agent-support sync        # 4不変条件に正規化（冪等）
agent-support status      # 現在の状態を視覚的に表示
agent-support check       # CI 用。違反があれば exit 1
```

引数なしで実行すると `status` が表示されます。

### サブコマンド一覧

| コマンド | 用途 | 主なオプション |
|---|---|---|
| `sync` | 4不変条件への冪等な正規化 | `--path <dir>` / `--dry-run` / `-v, --verbose` |
| `check` | CI 向け検査（違反で exit 1、stderr に項目出力） | `--path <dir>` |
| `status` | 人間向けの状態表示（常に exit 0） | `--path <dir>` |

### `sync` の正規化ルール

#### `CLAUDE.md`

| 現状 | 動作 |
|---|---|
| 存在しない | `CLAUDE.md → AGENTS.md` の相対 symlink を作成 |
| 既に正しい symlink | 何もしない |
| 別ターゲットへの symlink | エラー（手動対応） |
| 通常ファイル | `AGENTS.md` に追記マージ後、`CLAUDE.md` を削除して symlink |

マージ仕様:

- `AGENTS.md` が空 → `CLAUDE.md` の内容をそのまま移動
- 内容が完全一致 → 追記せず `CLAUDE.md` のみ削除
- 内容が異なる → セパレータ `\n\n<!-- merged from CLAUDE.md by agent-support -->\n\n` を挟んで `AGENTS.md` 末尾に追記

#### `.claude/skills`

| 現状 | 動作 |
|---|---|
| 存在しない | `.claude/skills → ../.agents/skills` の相対 symlink を作成 |
| 既に正しい symlink | 何もしない |
| 別パスへの symlink | エラー（手動対応） |
| 通常ディレクトリ | 中身を `.agents/skills/` に `moveItem` し、`.claude/skills` を symlink に置換 |

同名エントリが `.claude/skills` と `.agents/skills` 両方に存在する場合は **エラー終了し、何も動かしません**（手動マージを促す）。

#### `.gitkeep`

`.agents/skills` が空のときのみ `.gitkeep` を配置します。中身が追加されたら次回 sync で自動的に削除されます。

## 実行例

クリーンなリポジトリで:

```bash
$ cd /path/to/repo
$ agent-support sync
$ agent-support status
agent-support status (/path/to/repo)
  ✓ AGENTS.md        file, 0 B
  ✓ CLAUDE.md        -> AGENTS.md
  ✓ .agents/skills   dir, 1 entries
  ✓ .claude/skills   -> ../.agents/skills
```

異常状態（CLAUDE.md が想定外の symlink）の場合:

```bash
$ agent-support status
agent-support status (/path/to/repo)
  ✓ AGENTS.md        file, 0 B
  ✗ CLAUDE.md        symlink -> OTHER.md (expected AGENTS.md)
  ⚠ .agents/skills   missing (run `agent-support sync`)
  ⚠ .claude/skills   missing (run `agent-support sync`)
```

マーカー:

- `✓` 不変条件を満たす
- `⚠` 修復可能（`sync` で解決）
- `✗` 手動対応が必要（想定外の symlink ターゲット等）

## 開発

```bash
make build       # release build (.build/release/agent-support)
make test        # swift test
make run         # swift run agent-support
make sync        # このリポジトリに対して sync を実行
make check       # このリポジトリに対して check を実行
make status      # このリポジトリに対して status を表示
make clean       # ビルド成果物削除
make help        # ヘルプ表示
```

### ディレクトリ構成

```
Sources/agent-support/
├── AgentSupport.swift             # @main, サブコマンドルート
├── Commands/{Sync,Check,Status}Command.swift
└── Core/
    ├── Workspace.swift            # パス解決と相対ターゲット定数
    ├── SymlinkManager.swift       # lstat 相当の状態判定 + 相対 symlink 作成
    ├── ClaudeMdNormalizer.swift   # CLAUDE.md ↔ AGENTS.md 正規化＆マージ
    ├── SkillsNormalizer.swift     # .claude/skills → .agents/skills 移行
    ├── StatusInspector.swift      # status/check 共通の状態検査
    ├── Reporter.swift             # ✓/⚠/✗ 出力フォーマット
    └── AgentSupportError.swift
Tests/agent-supportTests/          # XCTest による Normalizer 単体テスト
```

### 依存

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.3.0+

## ライセンス

MIT（予定）
