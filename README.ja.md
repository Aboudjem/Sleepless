<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <b>日本語</b> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> この翻訳はコミュニティまたは機械によって生成されたもので、英語版の README より内容が古い場合があります。正式な情報源は英語版です。最新かつ正確な内容は [English README](README.md) を参照してください。

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <b>蓋を閉じても、バッテリー駆動でも、外部ディスプレイがなくても、MacBook をスリープさせない。</b><br>
  ネイティブなメニューバーのスイッチひとつ。バッテリー下限の自動オフ機能付きで、バッテリーを傷めることもありません。
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
  <img alt="Sleepless demo: toggle the switch, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

---

## 何ができるか

MacBook の蓋を閉じればスリープします。たいていはそれが望ましい動作ですが、夜通しのビルド、長いダウンロード、エージェントの実行、あるいは個人用ホットスポットを、ラップトップをバッグに入れたまま動かし続けたいときには困ります。

**Sleepless** は、蓋を閉じても Mac を起きたままにする唯一の本物のシステム設定 `pmset disablesleep` を切り替える小さなメニューバーアプリです。さらに自動の**バッテリー下限自動オフ**で守るので、「オン」のまま忘れてもバッテリーを消耗させたり熱をこもらせたりすることはありません。

- 🌙 **ネイティブなスイッチひとつ。** メニューバーの月をクリックしてトグルを切り替えるだけ。グリフが状態をひと目で示します。中抜きの `moon`（オフ）、塗りつぶしの `moon.fill`（オン）、`moon.stars.fill`（アーム状態: バッテリー駆動で起きていて自動オフが有効）。
- 🔋 **バッテリー下限の自動オフ。** スライダー（5〜50%、デフォルト 15%）をドラッグします。起きていて放電中のとき、その下限に達すると Sleepless は自動的にオフになります。
- 🖥️ **外部ディスプレイも電源アダプタもダミードングルも不要。** 蓋を閉じてバッテリー駆動、それだけで動きます。
- 🪶 **ネイティブで小さい。** AppKit + SF Symbols。Dock アイコンなし、サードパーティ依存なし、バックグラウンドのデーモンなし、kext なし。アプリ全体がたった一つの `App.swift` です。
- 🔍 **状態に正直。** トグルのたびにライブのシステム値を読み戻すので、スイッチは希望的観測ではなく常に実際の状態を反映します。

## インストール

### Homebrew（推奨）

```sh
brew install --cask aboudjem/tap/sleepless
```

これで `Aboudjem/homebrew-tap` がタップされ、`Sleepless.app` がインストールされます。次に、パスワードを求められずにスリープを切り替えられるよう、（アプリに同梱された）一度きりの権限付与を実行します。何を書き込むのかを確認のうえで表示してから尋ねてきます。

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

### リリース版をダウンロード

[**Releases**](https://github.com/Aboudjem/Sleepless/releases/latest) から `Sleepless-1.0.0.zip` を入手し、解凍して `Sleepless.app` を `/Applications` に移動します。アドホック署名（公証なし）のため、macOS Gatekeeper が初回起動をブロックします。**システム設定 → プライバシーとセキュリティ → このまま開く** を選んでください。（macOS 15 以降では、従来の右クリック → 開く という手は使えなくなりました。）

### ソースからビルド（Gatekeeper のプロンプトなし）

信頼モデルは「ソースを読んで自分でビルドする」ことです。ローカルでビルドしたアプリは隔離（quarantine）されないので、そのまま起動します。

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./install.sh        # builds, installs to /Applications, adds the grant + login item
```

`./build.sh` だけなら `build/Sleepless.app` を生成するだけです（Xcode 不要、Command Line Tools のみ）。`./uninstall.sh` はすべてを削除し、権限付与が消えたことを証明します。

## なぜ Sleepless が存在するのか

Apple の `caffeinate`（およびそれを土台にした KeepingYouAwake のようなあらゆるメニューバーアプリ）は、蓋を閉じた状態で Mac を起こし続けることが**できません**。それらが使う IOKit のパワーアサーションは、ハードウェアのクラムシェルスリープ（蓋を閉じたときのスリープ）のトリガーを上書きできないため、蓋を閉じれば必ず Mac はスリープします。クラムシェルスリープを上書きできる唯一のシステム上のレバーが `pmset disablesleep` です。

`disablesleep` に手を伸ばすツールはいくつかありますが、どれにも穴があります。Amphetamine はこれ（とそれ以上のこと）を実現しますが、その蓋を閉じた状態の経路は Apple Silicon 上で悪名高く不安定です。Macchiato はまさに同じ仕組みを使いますが、バッテリーガードを**まったく**備えていません。Clapet は**外部ディスプレイ**が接続されているときにしか作動しません。Sleepless は、ごく素朴なケース、つまり**蓋を閉じてバッテリー駆動、ディスプレイなし、忘れても安全な自動オフ付き**のために作られた、目的特化のオープンソースツールです。

## 比較

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 蓋を閉じてバッテリー駆動で起きたまま | ✅ | ✅¹ | ❌（拒否される） | ✅ | ⚠️ 外部ディスプレイが必要 | ❌ |
| 外部ディスプレイ不要 | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| バッテリー下限の自動オフ | ✅ | バッテリー低下時にセッション終了 | ✅（ただし蓋を閉じた状態は非対応） | ❌ | ❌ | ❌ |
| 仕組み | `pmset disablesleep` + 範囲を絞った sudoers | 公開 API ≈ `disablesleep` + IOKit | `caffeinate` | `pmset disablesleep` + ヘルパー | `pmset` + sudoers | IOKit アサーション |
| オープンソース | ✅ MIT | ❌（App Store） | ✅ MIT | ✅ Apache-2.0 | ✅ GPL-3.0 | Apple 標準搭載 |
| スター数 | 新規 | App Store | 約 6.6k | 約 18 | 約 101 | 該当なし |

<sub>¹ Amphetamine はこれをサポートしていますが、Apple Silicon では別途インストールする「Power Protect」スクリプトに依存しており、電源の接続・切断時や KVM／ドック構成で動作しなくなるとの報告が広く寄せられています。スター数は 2026-06-01 時点のもので、時間とともに変動します。競合に関するすべての記載はリサーチノートに出典があります。訂正は歓迎します。</sub>

## ユースケース

いずれもバッテリー下限と組み合わせて使います。納得できる下限を設定して、あとは放っておくだけです。

- **離席後に長時間ジョブを最後までやり切る。** エージェント／Claude の実行、レンダリング、コンパイル、ML 学習、大きな `brew`／`npm` のインストールなど。Sleepless をオンにして蓋を閉じ、バッグに入れれば動き続けます。
- **ホットスポットを共有したまま歩き回る。** Mac からの「インターネット共有」（Personal Hotspot / Internet Sharing）が蓋を閉じても維持されます。
- **無人での転送。** 大容量のダウンロードやアップロード、あるいは離席中に完了させたい Time Machine／バックアップの実行。
- **サーバーや SSH セッションを到達可能に保つ。** ローカルの開発サーバー、SSH セッション、同期デーモンが蓋を閉じても生き続けます。
- **オーディオを流し続ける。** 音楽、長尺の配信、オーディオのレンダリングがバッグの中でも再生され続けます。

## セキュリティモデル

Sleepless は root 権限のごく狭い一部だけを求めます。それが具体的に何なのかをここで説明します。完全な脅威モデルは [SECURITY.md](SECURITY.md) にあります。

GUI アプリにはパスワードを入力するターミナルがないため、`install.sh` はあなたのユーザー名を差し込んだ、厳密に範囲を絞った `/etc/sudoers.d` のドロップインファイル（所有者 `root:wheel`、モード `0440`）を書き込みます。

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **許可するのはちょうど 2 つのコマンドだけで、それ以外は一切許可しません。** sudoers は引数を文字どおりに照合し、このルールにはワイルドカードがないため、`sudo pmset -a sleep 0`、`pmset restoredefaults`、その他あらゆる手段は素通りせずパスワードを要求されます。この権限付与を広げることはできません。
- **シェルもヘルパースクリプトもなし。** アプリは argv 配列で `sudo` を呼び出し（`/bin/sh -c` は使いません）、ルールは Apple の `/usr/bin/pmset` を直接指しています。攻撃者が書き換えられるユーザー書き込み可能なスクリプトは存在しません。
- **`disablesleep` は非公開だが実在する。** `man pmset` には載っていませんが、カーネルの `SleepDisabled` フラグを設定します（`pmset -g | grep SleepDisabled`）。非公開のため Apple が変更する可能性はありますが、Sleepless はトグルのたびに値を読み戻します。
- **再起動すれば `0` にリセットされる。** これはランタイムのフラグなので、Mac を永久にスリープできない状態にしてしまうことはありません。バッテリー下限は二重の安全網です。
- **正直に言う残存リスク:** この権限付与は設計上パスワード不要なので、あなたとして動作するプロセスならどれでもこのフラグを切り替えられます。最悪のケースは「Mac が起きたままになった、またはスリープを許された」ことであって、データ損失や root でのコード実行ではありません。
- **きれいにアンインストールできる。** `./uninstall.sh` はアプリ、ログイン項目、権限付与を削除し、`sudo -n pmset …` が再びパスワードを求めることを示して取り消しを証明します。

## FAQ

**本当に蓋を閉じてバッテリー駆動、ディスプレイなしで Mac を起きたままにできますか?**
はい、それがまさに目的のすべてです。macOS 26（Tahoe）／ Apple Silicon で検証済みです。

**メニューバーに月が表示されません。** macOS 26 はメニューバーの項目を隠すことがあります。システム設定（コントロールセンター／メニューバーの設定）を確認し、Sleepless が項目を表示できるよう許可されているか確かめてください。`pgrep -x Sleepless` が数字を表示すれば、アプリは動作しています。

**なぜ公証されていないのですか?** これは有料の Apple Developer ID を持たない、個人のオープンソースツールなので、アドホック署名になっています。Gatekeeper を完全に回避するにはソースからビルドするか、ビルド済みアプリには **このまま開く** のフローを使ってください。そもそも公証はマルウェアでないことの保証にはなりません。

**バッテリーを消耗させませんか?** 下限を無視した場合だけです。起きていて放電中のとき、Sleepless は設定したバッテリー残量（デフォルト 15%）でオフになり、再起動すれば常に通常のスリープに戻ります。

**Intel Mac や古い macOS でも動きますか?** 検証済みなのは **macOS 26 Apple Silicon** です。`disablesleep` は非公開のため、他のバージョンやハードウェアでの挙動は保証されません。試して結果を教えてください。正直な報告を歓迎します。

**完全に削除するにはどうすればいいですか?** `./uninstall.sh` を実行します（あるいは `/Applications/Sleepless.app` を削除し、`sudo rm` で `/etc/sudoers.d/sleepless-disablesleep` を削除し、ログイン項目を `launchctl bootout` します）。

## コントリビュート

Issue と PR を歓迎します。特に翻訳や、他のハードウェア／macOS バージョンでの正直なテスト報告は大歓迎です。[CONTRIBUTING.md](CONTRIBUTING.md) と [行動規範](CODE_OF_CONDUCT.md) を参照してください。Sleepless はあえて小さく保ちます。権限の表面積を広げる機能が取り込まれることはまずありません。

## ライセンス

[MIT](LICENSE) © 2026 Adam Boudjemaa.

---

<p align="center">
  <sub>Sleepless のおかげでターミナルを開かずに済んだなら、⭐ をつけると他の人が見つけやすくなります。</sub>
</p>

