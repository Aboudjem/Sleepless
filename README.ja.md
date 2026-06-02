<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <b>日本語</b> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>フタを閉じても、バッテリー駆動でも、外部ディスプレイなしでも MacBook をスリープさせない。</b><br>
  <sub>メニューバーのスイッチひとつ。自動オフタイマーとバッテリー下限カットオフ付きなので、うっかり空っぽにする心配もありません。</sub>
</p>

<p align="center">
  <a href="https://github.com/Aboudjem/Sleepless/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Aboudjem/Sleepless/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white&style=flat-square&color=8B5CF6"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aboudjem/Sleepless?label=release&logo=apple&logoColor=white&style=flat-square&color=8B5CF6"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aboudjem/Sleepless/total?label=downloads&style=flat-square&color=6366F1"></a>
  <a href="https://github.com/Aboudjem/Sleepless/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Aboudjem/Sleepless?style=flat-square&color=6366F1"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-D946EF?style=flat-square"></a>
  <img alt="Platform: macOS 26, Apple Silicon" src="https://img.shields.io/badge/macOS%2026-Apple%20Silicon-8B5CF6?style=flat-square&logo=apple&logoColor=white">
</p>
<p align="center">
  <img alt="Build provenance: attested (SLSA)" src="https://img.shields.io/badge/build%20provenance-attested-8B5CF6?style=flat-square&logo=githubactions&logoColor=white">
  <img alt="Checksums: SHA-256" src="https://img.shields.io/badge/checksums-SHA--256-6366F1?style=flat-square">
  <img alt="Telemetry: none" src="https://img.shields.io/badge/telemetry-none-D946EF?style=flat-square">
  <a href="https://github.com/Aboudjem/homebrew-tap"><img alt="Install: Homebrew cask" src="https://img.shields.io/badge/homebrew-cask-8B5CF6?style=flat-square&logo=homebrew&logoColor=white"></a>
</p>

<p align="center">
  <img alt="Sleepless demo: flip the switch, set an auto-off timer, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

> [!NOTE]
> フタを閉じると Mac はスリープし、`caffeinate` 系アプリ（KeepingYouAwake やその仲間）は仕様上それを変えられません。Sleepless はそれを変えられる唯一の設定 `pmset disablesleep` を切り替え、安全装置を備えているので安心して放っておけます。

## インストール

```sh
brew install --cask aboudjem/tap/sleepless
/Applications/Sleepless.app/Contents/Resources/grant.sh   # one-time passwordless grant
```

| その他の方法 | |
|---|---|
| **ダウンロード** | [最新リリース](https://github.com/Aboudjem/Sleepless/releases/latest) を入手し、`/Applications` に解凍してから、**システム設定 → プライバシーとセキュリティ → このまま開く** で許可します（アドホック署名のため）。 |
| **ソースからビルド** | `git clone https://github.com/Aboudjem/Sleepless.git && cd Sleepless && ./install.sh`（Gatekeeper の確認は出ません）。 |

あとはメニューバーのカップをクリックし、スイッチを入れて、フタを閉じるだけです。

## 機能

| | | |
|---|---|---|
| ☕ | **スイッチひとつ** | メニューバーのカップをクリックし、トグルを切り替えるだけ。 |
| ⏲️ | **自動オフタイマー** | 1 時間または 2 時間、ライブのカウントダウン付きで、終わると自動でオフ。 |
| 🔋 | **バッテリー下限** | バッテリー駆動時に 5〜50% で自動オフ（初期値 15%）。 |
| 🪫 | **Low Power Mode** | バッテリー駆動で LPM がオンのときは身を引きます。 |
| 🖥️ | **ドングル不要** | フタを閉じてバッテリー駆動。モニターも HDMI プラグも不要。 |
| 🚀 | **ログイン時に起動** | 任意で、初期状態はオフ。必ずオフの状態で起動します。 |
| 🪶 | **小さくてネイティブ** | AppKit ファイル 1 つ。Dock アイコンも、デーモンも、kext もなし。 |

**メニューバーのグリフ:** 空のカップ＝オフ・満たされたカップ＝スリープ防止オン・満たされたカップにドット＝バッテリー駆動でスリープ防止（自動オフ作動中）。

## Sleepless と他の選択肢の比較

| | **Sleepless** | Amphetamine | KeepingYouAwake | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| フタを閉じ、モニターなしでスリープしない | ✅ ¹ | ⚠️ ² | ❌ ³ | ❌ |
| バッテリー駆動 | ✅ | ✅ | ✅ フタ開き | ⚠️ ⁴ |
| 自動オフタイマー | ✅ | ✅ | ✅ | ❌ |
| 低残量で自動オフ | ✅ | ✅ | ✅ | ❌ |
| オープンソース | ✅ MIT | ❌ App Store | ✅ MIT | Apple |
| 価格 | 無料 | 無料 | 無料 | 無料 |

<sub>2026-06 時点。¹ `pmset disablesleep` を使い、フラグを読み戻します。挙動はハードウェアと macOS のバージョンに依存します。² クローズドディスプレイモードを文書化していますが、電源の切り替え時に Apple Silicon で動作しなくなるという報告が広く寄せられています（[AE #28](https://github.com/x74353/Amphetamine-Enhancer/issues/28)）。アプリはクローズドソースです。³ 仕様上フタ閉じはできず、`caffeinate` をラップしています（[#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)）。⁴ `caffeinate -i` はバッテリー駆動で動きますが、`-s` は AC 電源時のみです。</sub>

## こんな使い方に

- 🤖 フタを閉じたまま一晩のジョブを完了：エージェントの実行、ビルド、レンダリング、ML 学習。
- 📡 カバンの中からホットスポットを共有。
- ⬇️ 大きなダウンロード、アップロード、バックアップを実行したまま離席。
- 🖥️ ローカルサーバーや SSH セッションを到達可能なまま維持。

> [!TIP]
> 信頼できるバッテリー下限（たとえば 20%）とタイマーを設定しておけば、バッテリーを気にせず席を離れられます。

## 仕組み

Sleepless は `pmset disablesleep`（カーネルの `SleepDisabled` フラグ）を切り替え、値を読み戻すのでメニューバーが嘘をつくことはなく、バッテリー下限に達したとき、Low Power Mode のとき、タイマーが切れたとき、または再起動時に元へ戻します。GUI アプリはパスワードを入力できないため、インストーラーは**ちょうど 2 つのコマンド**だけを許可する、範囲を絞った sudoers ルールを追加します。

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **範囲を広げられません。** sudoers はワイルドカードなしで引数を文字どおり照合します。
- **乗っ取る対象がありません。** デーモンも、ヘルパースクリプトも、シェルもなし。`/usr/bin/pmset` を直接呼び出します。
- **常に元に戻せます。** 再起動、下限、タイマー、または `./uninstall.sh`（権限がなくなったことも確認します）。

Apple アカウントなしでダウンロードを検証できます。

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Sleepless-*.zip -R Aboudjem/Sleepless
```

完全な脅威モデル、App Store に出せない理由、監査ガイドは [SECURITY.md](SECURITY.md) · [docs/AUDIT.md](docs/AUDIT.md) にあります。

## FAQ

<details>
<summary><b><code>pmset disablesleep</code> は Apple Silicon（M1/M2/M3）でもまだ機能する？</b></summary>

はい、macOS 26.3 で確認済みです。`pmset -a disablesleep 1` は Apple Silicon でカーネルの `SleepDisabled` フラグを立て、バッテリー駆動でフタを閉じたまま Mac を起こし続けます。`pmset -g | grep SleepDisabled` で確認できます（`1` と表示されるはずです）。「もう動かない」という主張の多くは、別の仕組みである `caffeinate` や caffeinate 系アプリの話です。
</details>

<details>
<summary><b>Amphetamine や KeepingYouAwake を使っても蓋を閉じると Mac がスリープするのはなぜ？</b></summary>

それらは macOS の power assertion を使っており、アイドルタイマーは止められますが、ハードウェアのフタ閉じトリガーは上書きできません。KeepingYouAwake は `caffeinate` をラップしているため、フタ閉じには対応できません（[#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)）。Sleepless が使う `pmset disablesleep` はそれができます。
</details>

<details>
<summary><b>安全？ 発熱やバッテリーの消耗は？</b></summary>

ダウンロード、同期、ホットスポットのような軽い無人作業なら安全です。フタを完全に閉じたまま重い負荷を持続させると通気が悪くなるので、見極めが必要です。バッテリー下限、Low Power Mode での自動オフ、タイマーが、Mac を空にする前に止めてくれます。
</details>

<details>
<summary><b>sudo、カーネル拡張、デーモンは必要？</b></summary>

GUI アプリが確認なしで設定を切り替えられるよう、厳密に範囲を絞った `sudo` 権限が 1 つだけ必要です（ちょうど 2 つの `pmset` コマンドのみ）。カーネル拡張もデーモンもありません。アプリ全体が AppKit ファイル 1 つです。
</details>

<details>
<summary><b>止めたり削除したりするには？</b></summary>

スイッチをオフにするか、タイマーまたはバッテリー下限に任せれば、通常のスリープが戻ります。再起動でもリセットされます。`./uninstall.sh` はアプリ、ログイン項目、sudoers の権限を削除したうえで、その権限がなくなったことを確認します。
</details>

<details>
<summary><b>なぜ公証（notarized）されていないのですか？</b></summary>

有料の Apple Developer ID を持たない、個人のオープンソースツールなので、アドホック署名になっています。Gatekeeper を回避するにはソースからビルドするか、ビルド済みアプリでは **このまま開く** を使ってください。公証の手順は [docs/AUDIT.md](docs/AUDIT.md) に記載しています。
</details>

## コントリビューション

Issue や PR を歓迎します。特に翻訳や、他のハードウェアでのテスト報告は大歓迎です。[CONTRIBUTING.md](CONTRIBUTING.md) と [行動規範](CODE_OF_CONDUCT.md) をご覧ください。Sleepless はあえて小さく保たれています。

## ライセンス

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Sleepless のおかげでターミナルを開かずに済んだなら、⭐ をつけてもらえると他の人にも見つけてもらいやすくなります。</sub>
</p>
