# discord.mbt

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Dave](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml)
[![Voice shim](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml)
[![Ask DeepWiki](https://img.shields.io/badge/Ask-DeepWiki-blue)](https://deepwiki.com/gaato/discord.mbt)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](LICENSE)

[MoonBit](https://www.moonbitlang.com) 向けの Discord ライブラリです。Gateway のスラッシュコマンドのボット、Cloudflare Workers・Deno・native サーバー上のインタラクションのエンドポイント、REST のツール、ボイスを作れます。非公式で、Discord とは関係ありません。このリポジトリは MoonBit のワークスペースで、下の各ディレクトリがモジュールです。

[English](README.md)

| ディレクトリ | モジュール | 中身 |
| --- | --- | --- |
| [`discord/`](discord/README.md) | [`gaato/discord`](https://mooncakes.io/docs/gaato/discord) | REST、インタラクション、Gateway のボット |
| [`discord_voice/`](discord_voice/README.md) | [`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice) | `gaato/discord` のボットのボイス(native) |
| [`dave/`](dave/README.md) | [`gaato/dave`](https://mooncakes.io/docs/gaato/dave) | DAVE のエンドツーエンド暗号化のための、Discord の `libdave` へのバインディング |
| [`examples/`](examples/README.md) | (未公開) | 動かせるボット、HTTP のインタラクションサーバー、JavaScript ホストのアダプター |
| [`guide/`](guide/README.md) | (未公開) | コードがテストされる長めのガイド |
| [`template/`](template/README.md) | (未公開) | 写して使うボットのプロジェクト |

ほかのディレクトリ: [`docs/`](docs) には REST のふるまいのメモと、保守者向けの台帳・設計メモがあります。[`scripts/`](scripts/README.md) には監査とリリースの道具が、`experiments/` にはホストの実験があります。公開している各モジュールには、それぞれ `CHANGELOG.md` があります。

使い方は [`discord/README.md`](discord/README.md) にあります。同じ REST API を使うコマンドラインの道具は [discord-cli](https://github.com/gaato/discord-cli) です。不具合や要望は [Issues](https://github.com/gaato/discord.mbt/issues) へどうぞ。

## 開発

ワークスペースでのビルドとテスト、開発用のイメージ、保守者向けの文書は、英語版の [Development](README.md#development) にあります。

## ライセンス

Apache-2.0 です。
