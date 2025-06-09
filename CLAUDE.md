# marp.nvim - Claude Code Configuration

このファイルは、marp.nvimプロジェクトの開発をClaude Codeで効率的に行うための設定とガイドラインです。

## プロジェクト概要

marp.nvimは、[Marp](https://marp.app/)（Markdown Presentation Ecosystem）用のNeovimプラグインです。マークダウンファイルからプレゼンテーションを作成し、リアルタイムプレビューや各種形式でのエクスポート機能を提供します。

## ディレクトリ構造

```
marp.nvim/
├── lua/
│   └── marp.lua          # メインのLuaモジュール
├── plugin/
│   └── marp.vim          # Vimコマンド定義
├── doc/
│   ├── marp.txt          # ヘルプドキュメント
│   └── tags              # ヘルプタグ
├── README.md             # プロジェクト説明（日英両対応）
├── LICENSE               # ライセンス
├── Makefile              # ビルド・テスト自動化
└── CLAUDE.md             # このファイル
```

## 開発ワークフロー

### 品質チェックコマンド

開発時は以下のコマンドを使用してコードの品質を保ちます：

```bash
# すべてのチェックを実行
make check

# Luaチェックのみ
make lint

# コードフォーマットチェック
make format-check

# コードフォーマット実行
make format

# テスト実行
make test
```

### CI/CD連携

**重要**: コミット前に必ずローカルで品質チェックを実行してください。

CIでは以下のチェックが自動実行されます：
1. **luacheck**: Lua コードの静的解析（.luacheckrc設定）
2. **stylua**: コードフォーマットチェック（.stylua.toml設定）

ローカルでCIと同じチェックを実行：
```bash
# CI環境と同じチェックを実行
make check

# 個別実行
luacheck lua/ plugin/                              # luacheckのみ
stylua --check lua/ plugin/ --glob '**/*.lua'      # styluaチェックのみ
stylua lua/ plugin/ --glob '**/*.lua'              # stylua自動修正
```

設定ファイル：
- `.luacheckrc`: luacheck設定（Lua 5.1、vim globals、行長制限なし）
- `.stylua.toml`: stylua設定（120文字幅、2スペースインデント、Unix改行）
- `.github/workflows/lint.yml`: CI設定（push/PR時に自動実行）

### コーディング規約

- **Lua**: luacheckとstyluaの設定に従う
- **Vim script**: 最小限に抑え、主要ロジックはLuaで実装
- **コメント**: 機能説明は控えめに、必要な場合のみ記述
- **エラーハンドリング**: vim.notifyを使用してユーザーに適切なフィードバック

## 主要機能

### コアコマンド
- `:MarpWatch` - ライブプレビュー開始
- `:MarpStop` - プレビュー停止  
- `:MarpExport [format]` - エクスポート（html/pdf/pptx/png/jpeg）
- `:MarpTheme [theme]` - テーマ設定
- `:MarpSnippet [name]` - スニペット挿入
- `:MarpDebug` - 診断実行

### 重要な実装詳細

1. **プロセス管理**: `M.active_processes`でバッファごとのMarpプロセスを追跡
2. **自動クリーンアップ**: バッファ削除時にプロセスを自動停止
3. **デュアルモード**: サーバーモード(-s)とウォッチモード(--watch)をサポート
4. **デバッグ支援**: 詳細ログとエラー診断機能

## ファイル固有の注意点

### lua/marp.lua
- メイン実装ファイル（714行）
- 設定管理、プロセス制御、UI統合をすべて担当
- ANSI エスケープシーケンスのクリーニング処理を含む
- デバッグモードの詳細な出力制御

### plugin/marp.vim  
- Vimコマンド定義のみ（42行）
- タブ補完機能を含む
- Luaモジュールへのブリッジ役

## 開発時の推奨アプローチ

1. **機能追加**: まずlua/marp.luaで実装、必要に応じてplugin/marp.vimにコマンド追加
2. **バグ修正**: デバッグモードを活用して問題箇所を特定
3. **リファクタリング**: 品質チェックコマンドで検証しながら実施
4. **テスト**: minimal_init.luaを使用した軽量テスト環境を活用

## 外部依存関係

- **Neovim 0.5+**
- **Marp CLI**: npmパッケージ、npx経由でも利用可能
- **開発ツール**: luacheck, stylua（品質管理用）

## 設定例

```lua
require('marp').setup({
  marp_command = "/opt/homebrew/opt/node/bin/node /opt/homebrew/bin/marp",
  browser = nil,  -- 自動検出
  debug = true,   -- 開発時はtrueを推奨
  server_mode = false,  -- ウォッチモード使用
  show_tips = true,
  auto_copy_path = true,
})
```

## トラブルシューティング

- `:MarpDebug`コマンドでMarp CLI環境を診断
- `debug = true`設定で詳細ログを確認
- プロセス状況は`:MarpList`で確認
- HTML生成パスは自動的にクリップボードにコピー