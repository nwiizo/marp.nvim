# marp.nvim

A Neovim plugin for [Marp](https://marp.app/) (Markdown Presentation Ecosystem).

[日本語版](#日本語)

## Features

- 🔄 **Live Preview**: Watch mode with auto-refresh and real-time HTML generation (`MarpWatch`)
- 🛑 **Auto Cleanup**: Automatically stops Marp server when buffer is closed
- 📤 **Export**: Export presentations to HTML, PDF, PPTX, PNG, JPEG
- 🎨 **Theme Support**: Easily switch between Marp themes
- ✂️ **Snippets**: Insert common Marp elements quickly
- 🖥️ **Preview**: One-time preview without watch mode
- 🔧 **Dual Mode**: Support both server mode (-s) and watch mode (--watch)
- 🐛 **Debug Mode**: Detailed logging for troubleshooting

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'nwiizo/marp.nvim',
  config = function()
    require('marp').setup({
      -- Optional configuration
      marp_command = "npx @marp-team/marp-cli@latest",
      browser = nil, -- auto-detect
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'nwiizo/marp.nvim',
  config = function()
    require('marp').setup()
  end
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:MarpWatch` | Start watching current file and open in browser |
| `:MarpStop` | Stop watching current buffer |
| `:MarpStopAll` | Stop all Marp servers |
| `:MarpPreview` | One-time preview (opens and exits) |
| `:MarpList` | List all active Marp servers |
| `:MarpExport [format]` | Export to format (html/pdf/pptx/png/jpeg) |
| `:MarpTheme [theme]` | Set theme (default/gaia/uncover) |
| `:MarpSnippet [name]` | Insert snippet |
| `:MarpInfo` | Show current Marp information |
| `:MarpCopyPath` | Copy HTML file path to clipboard |
| `:MarpDebug` | Run diagnostics to check Marp setup |

## Available Snippets

- `title` - Title slide with author and date
- `columns` - Two-column layout
- `image` - Image markdown
- `bg_image` - Background image directive
- `center` - Centered content
- `speaker_notes` - Speaker notes comment

## Configuration

```lua
require('marp').setup({
  -- Marp CLI command (uses local marp if available)
  marp_command = "npx @marp-team/marp-cli@latest",
  
  -- Browser command (nil = auto-detect)
  browser = nil,
  
  -- Available themes
  themes = {
    default = "default",
    gaia = "gaia",
    uncover = "uncover"
  },
  
  -- Export formats
  export_formats = {
    html = "--html",
    pdf = "--pdf",
    pptx = "--pptx",
    png = "--images png",
    jpeg = "--images jpeg"
  },
  
  -- New features
  show_tips = true,           -- Show helpful tips
  auto_copy_path = true,      -- Auto-copy file paths to clipboard
  show_file_size = true,      -- Show file sizes after export
  suggest_gitignore = true,   -- Suggest adding *.html to .gitignore
  debug = false,              -- Enable debug logging (helpful for troubleshooting)
  server_mode = false         -- Use server mode (-s) or watch mode (--watch)
})
```

## Usage Example

1. Open a markdown file
2. Run `:MarpWatch` to start live preview
3. Edit your presentation - changes appear instantly
4. Close the buffer or run `:MarpStop` to stop the server

## Requirements

- Neovim 0.5+
- [Marp CLI](https://github.com/marp-team/marp-cli) (auto-installed via npx if not found)

## Troubleshooting

### Watch mode not opening browser

If `:MarpWatch` doesn't open the browser automatically:

1. Run `:MarpDebug` to check if Marp CLI is properly installed
2. Enable debug mode to see detailed output:
   ```lua
   require('marp').setup({ debug = true })
   ```
3. Make sure you have a default browser set on your system
4. Try manually opening the HTML file path (shown in the notification or copied to clipboard)

### File changes not detected

The plugin uses `--watch` mode by default. If changes aren't detected:

1. Check if the Marp process is running: `:MarpList`
2. Try stopping and restarting: `:MarpStop` then `:MarpWatch`
3. Ensure the markdown file is saved to trigger updates
4. Enable debug mode to see Marp output: `require('marp').setup({ debug = true })`

### Server mode vs Watch mode

By default, the plugin uses watch mode (`--watch`) which generates HTML files and watches for changes. You can switch to server mode (`-s`) which serves files via HTTP:

```lua
require('marp').setup({ server_mode = true })
```

---

# 日本語

[Marp](https://marp.app/)（Markdownプレゼンテーションエコシステム）用のNeovimプラグインです。

## 機能

- 🔄 **ライブプレビュー**: 自動更新とリアルタイムHTML生成付きのウォッチモード（`MarpWatch`）
- 🛑 **自動クリーンアップ**: バッファを閉じると自動的にMarpサーバーが停止
- 📤 **エクスポート**: HTML、PDF、PPTX、PNG、JPEGへのエクスポート
- 🎨 **テーマサポート**: Marpテーマの簡単な切り替え
- ✂️ **スニペット**: よく使うMarp要素を素早く挿入
- 🖥️ **プレビュー**: ウォッチモードなしの一回限りのプレビュー
- 🔧 **デュアルモード**: サーバーモード(-s)とウォッチモード(--watch)の両方をサポート
- 🐛 **デバッグモード**: トラブルシューティング用の詳細ログ

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)を使用

```lua
{
  'nwiizo/marp.nvim',
  config = function()
    require('marp').setup({
      -- オプション設定
      marp_command = "npx @marp-team/marp-cli@latest",
      browser = nil, -- 自動検出
    })
  end
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)を使用

```lua
use {
  'nwiizo/marp.nvim',
  config = function()
    require('marp').setup()
  end
}
```

## コマンド

| コマンド | 説明 |
|---------|------|
| `:MarpWatch` | 現在のファイルの監視を開始しブラウザで開く |
| `:MarpStop` | 現在のバッファの監視を停止 |
| `:MarpStopAll` | すべてのMarpサーバーを停止 |
| `:MarpPreview` | 一回限りのプレビュー |
| `:MarpList` | アクティブなMarpサーバーを一覧表示 |
| `:MarpExport [形式]` | 指定形式でエクスポート (html/pdf/pptx/png/jpeg) |
| `:MarpTheme [テーマ]` | テーマを設定 (default/gaia/uncover) |
| `:MarpSnippet [名前]` | スニペットを挿入 |
| `:MarpInfo` | 現在のMarp情報を表示 |
| `:MarpCopyPath` | HTMLファイルパスをクリップボードにコピー |
| `:MarpDebug` | Marpセットアップの診断を実行 |

## 利用可能なスニペット

- `title` - タイトルスライド（著者と日付付き）
- `columns` - 2カラムレイアウト
- `image` - 画像マークダウン
- `bg_image` - 背景画像ディレクティブ
- `center` - 中央揃えコンテンツ
- `speaker_notes` - スピーカーノートコメント

## 設定

```lua
require('marp').setup({
  -- Marp CLIコマンド（ローカルのmarpがあれば使用）
  marp_command = "npx @marp-team/marp-cli@latest",
  
  -- ブラウザコマンド（nil = 自動検出）
  browser = nil,
  
  -- 利用可能なテーマ
  themes = {
    default = "default",
    gaia = "gaia",
    uncover = "uncover"
  },
  
  -- エクスポート形式
  export_formats = {
    html = "--html",
    pdf = "--pdf",
    pptx = "--pptx",
    png = "--images png",
    jpeg = "--images jpeg"
  },
  
  -- 新機能
  show_tips = true,           -- 便利なヒントを表示
  auto_copy_path = true,      -- ファイルパスを自動でクリップボードにコピー
  show_file_size = true,      -- エクスポート後にファイルサイズを表示
  suggest_gitignore = true,   -- *.htmlを.gitignoreに追加するよう提案
  debug = false,              -- デバッグログを有効化（トラブルシューティングに便利）
  server_mode = false         -- サーバーモード(-s)またはウォッチモード(--watch)を使用
})
```

## 使用例

1. マークダウンファイルを開く
2. `:MarpWatch`でライブプレビューを開始
3. プレゼンテーションを編集 - 変更が即座に反映されます
4. バッファを閉じるか`:MarpStop`でサーバーを停止

## 必要要件

- Neovim 0.5以上
- [Marp CLI](https://github.com/marp-team/marp-cli)（見つからない場合はnpx経由で自動インストール）

## トラブルシューティング

### ウォッチモードでブラウザが開かない

`:MarpWatch`でブラウザが自動的に開かない場合：

1. `:MarpDebug`を実行してMarp CLIが正しくインストールされているか確認
2. デバッグモードを有効にして詳細な出力を確認：
   ```lua
   require('marp').setup({ debug = true })
   ```
3. システムにデフォルトブラウザが設定されているか確認
4. HTMLファイルパス（通知に表示またはクリップボードにコピー）を手動で開いてみる

### ファイルの変更が検出されない

プラグインはデフォルトで`--watch`モードを使用します。変更が検出されない場合：

1. Marpプロセスが実行中か確認：`:MarpList`
2. 停止して再起動を試す：`:MarpStop`の後に`:MarpWatch`
3. ファイルを保存して更新をトリガー
4. デバッグモードを有効にしてMarpの出力を確認：`require('marp').setup({ debug = true })`

### サーバーモード vs ウォッチモード

デフォルトでは、HTMLファイルを生成して変更を監視するウォッチモード（`--watch`）を使用します。HTTPでファイルを提供するサーバーモード（`-s`）に切り替えることもできます：

```lua
require('marp').setup({ server_mode = true })
```