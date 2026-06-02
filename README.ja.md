<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <b>日本語</b> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> この翻訳はコミュニティまたは機械によって作成されたものであり、英語版の README より内容が古い場合があります。正となるのは英語版です。最新かつ正確な情報については [English README](README.md) を参照してください。

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Sleepless は、フタを閉じた状態でも、バッテリー駆動でも、外部ディスプレイなしでも、MacBook をスリープさせずに動かし続けます。</b><br>
  <sub>ネイティブなメニューバーのスイッチひとつ。指定したバッテリー残量で自動オフになるので、うっかり空っぽにしてしまう心配もありません。</sub>
</p>

<p align="center">
  <a href="https://github.com/Aboudjem/Sleepless/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Aboudjem/Sleepless/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aboudjem/Sleepless?label=release&logo=apple&logoColor=white"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aboudjem/Sleepless/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/Aboudjem/Sleepless?color=blue"></a>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-26%20·%20Apple%20Silicon-7c5cf0?logo=apple&logoColor=white">
  <a href="https://github.com/Aboudjem/Sleepless/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Aboudjem/Sleepless?style=social"></a>
</p>

<p align="center">
  <img alt="Sleepless demo: flip the switch, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

> [!NOTE]
> 通常、フタを閉じると Mac はスリープします。そして `caffeinate` ベースのアプリ（KeepingYouAwake やその仲間）には、これを変える**ことはできません**。Sleepless はそれを変えられる唯一の設定、`pmset disablesleep` を切り替え、さらにバッテリー残量による自動オフでガードするので、安心して放っておけます。

## できること

|  |  |
|---|---|
| 🌙 **スイッチひとつ** | メニューバーの月をクリックして、トグルを切り替えるだけ。グリフを見れば状態がひと目でわかります。 |
| 🔋 **バッテリー残量での自動オフ** | 下限を選びます（5〜50%、初期値は 15%）。バッテリー駆動時は、空になる前に自分でオフになります。 |
| 🖥️ **ディスプレイ不要、ドングル不要** | 必要なのはフタを閉じてバッテリー駆動にすることだけ。外部モニターもダミー HDMI プラグも要りません。 |
| 🪶 **小さくてネイティブ** | AppKit + SF Symbols。Dock アイコンなし、バックグラウンドのデーモンなし、kext なし、依存関係なし。 |

## インストール

**Homebrew**（推奨）:

```sh
brew install --cask aboudjem/tap/sleepless
# one-time: add the passwordless grant (it prints exactly what it writes first)
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

**ソースからビルド**（信頼できる方法: 読んで、ビルドして、Gatekeeper の確認も出ません）:

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless && ./install.sh
```

**またはアプリをダウンロード:** [最新リリース](https://github.com/Aboudjem/Sleepless/releases/latest) を入手し、解凍して、`Sleepless.app` を `/Applications` に移動します。アドホック署名されているため、初回起動時は **システム設定 → プライバシーとセキュリティ → このまま開く** で許可してください（右クリック → 開く という従来の方法は macOS 15 で廃止されました）。

あとは月をクリックし、スイッチを切り替えて、フタを閉じるだけ。`./uninstall.sh` ですべて削除され、付与した権限がなくなったことも確認できます。

## 仕組み

`caffeinate` とそれが使う power assertion では、ハードウェアによるフタ閉じトリガーを上書きできないため、フタを閉じれば Mac は必ずスリープします。これを上書きできる唯一のシステム設定が `pmset disablesleep` です。Sleepless はネイティブなスイッチからこれを切り替え、実際の値を読み戻すので UI が嘘をつくことはなく、設定したバッテリー残量で自動的に元に戻します。再起動でもリセットされます。[セキュリティモデルの詳細 →](SECURITY.md)

## Sleepless と他の選択肢の比較

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| フタを閉じ、バッテリー駆動でスリープしない | ✅ | ✅¹ | ❌ | ✅ | ⚠️ 外部ディスプレイ要 | ❌ |
| 外部ディスプレイ不要 | ✅ | ✅ | 該当なし | ✅ | ❌ | 該当なし |
| バッテリー残量での自動オフ | ✅ | 低残量のみ | ✅² | ❌ | ❌ | ❌ |
| オープンソース | ✅ MIT | ❌ App Store | ✅ MIT | ✅ Apache | ✅ GPL | Apple |

<sub>¹ Amphetamine は対応していますが、Apple Silicon では別途「Power Protect」スクリプトに依存しており、電源やドックの変更で動作しなくなるという報告が多く寄せられています。 &nbsp; ² KeepingYouAwake にはバッテリーカットオフがありますが、設計上、フタを閉じた状態でスリープを防ぐことはできません。スター数（約6.6k / 約18 / 約101）は 2026-06-01 時点のものです。訂正は歓迎します。</sub>

## こんな使い方に…

- 🤖 **席を離れた後に長時間のジョブを完了させる。** AI エージェントの実行、ビルド、レンダリング、ML 学習、大きな `brew`/`npm` のインストールなど。オンにしてフタを閉じ、カバンに入れて、戻ってくれば完了しています。
- 📡 **移動中にホットスポットを共有する。** Mac のインターネット共有 / 個人用ホットスポットは、フタを閉じても配信し続けます。
- ⬇️ **大きな転送を実行したままにする。** 大容量のダウンロードやアップロード、Time Machine のバックアップが、離席中に完了します。
- 🖥️ **サーバーや SSH セッションを生かしておく。** ローカルの開発サーバー、同期デーモン、リモートセッションが、フタを閉じても到達可能なまま保たれます。
- 🎧 **オーディオを再生し続ける。** 音楽や長いレンダリングが、カバンの中でも再生され続けます。

> [!TIP]
> バッテリーの下限を信頼できる値（たとえば 20%）に設定しておけば、バッテリーを気にせず上記すべてを実行できます。

## 安全ですか？

はい。そして監査できるように作られています。GUI アプリはパスワードを入力できないため、インストーラーは厳密に範囲を絞った `/etc/sudoers.d` ルール（root 所有、`0440`）を追加します。これが許可するのは**ちょうど 2 つのコマンドだけ、それ以外は一切なし**です:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **範囲を広げられません。** `sudoers` はワイルドカードなしで引数を文字どおり照合するため、他のコマンドはすべて改めてパスワードを要求します。
- 攻撃者に乗っ取られる**デーモンもヘルパースクリプトもありません。** Apple の `/usr/bin/pmset` を argv 配列で直接呼び出します（シェルは介しません）。
- **常に元に戻せます。** 再起動でフラグはリセットされ、バッテリーの下限でオフになり、`./uninstall.sh` で付与した権限が削除され、それも確認できます。

完全な脅威モデル、文書化されていないが実在する `disablesleep` の証拠、そして公証（notarization）のトレードオフについては **[SECURITY.md](SECURITY.md)** にまとめてあります。

## FAQ

<details>
<summary><b>本当にフタを閉じて、バッテリー駆動で、ディスプレイなしで動きますか？</b></summary>

はい、それこそが目的です。macOS 26 (Tahoe) / Apple Silicon で検証済みです。
</details>

<details>
<summary><b>メニューバーに月が表示されません。</b></summary>

macOS 26 はメニューバーの項目を隠すことがあります。システム設定（コントロールセンター / メニューバー）を確認し、Sleepless の項目を表示するよう許可してください。<code>pgrep -x Sleepless</code> で実行中かどうかを確認できます。
</details>

<details>
<summary><b>なぜ公証（notarized）されていないのですか？</b></summary>

これは有料の Apple Developer ID を持たない、個人のオープンソースツールなので、アドホック署名になっています。Gatekeeper を完全に回避するにはソースからビルドするか、ビルド済みアプリでは <b>このまま開く</b> のフローを使ってください。
</details>

<details>
<summary><b>バッテリーを消耗させませんか？</b></summary>

下限を無視した場合だけです。スリープを防いだまま放電している間は、設定した残量（初期値 15%）でオフになり、再起動すれば常に通常のスリープに戻ります。
</details>

<details>
<summary><b>Intel や古い macOS でも動きますか？</b></summary>

検証済みなのは <b>macOS 26 Apple Silicon</b> です。<code>disablesleep</code> は文書化されていないため、他のバージョンやハードウェアでの動作は保証されません。試してみて、結果を報告してください。正直な報告を歓迎します。
</details>

## コントリビューション

Issue や PR を歓迎します。特に翻訳や、他のハードウェアでのテスト報告は大歓迎です。[CONTRIBUTING.md](CONTRIBUTING.md) と [行動規範](CODE_OF_CONDUCT.md) をご覧ください。Sleepless はあえて小さく保たれています。

## ライセンス

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Sleepless のおかげでターミナルを開かずに済んだなら、⭐ をつけてもらえると他の人にも見つけてもらいやすくなります。</sub>
</p>

