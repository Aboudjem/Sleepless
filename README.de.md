<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <b>Deutsch</b>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Halte dein MacBook bei geschlossenem Deckel wach, im Akkubetrieb, ohne externen Bildschirm.</b><br>
  <sub>Ein Schalter in der Menüleiste, mit Abschalt-Timer und Abschaltung bei Akku-Mindeststand, damit du ihn nie ganz leerziehst.</sub>
</p>

<p align="center">
  <a href="https://github.com/Aboudjem/Sleepless/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Aboudjem/Sleepless/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white&style=flat-square"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aboudjem/Sleepless?label=release&logo=apple&logoColor=white&style=flat-square&color=B45309"></a>
  <a href="https://github.com/Aboudjem/Sleepless/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aboudjem/Sleepless/total?label=downloads&style=flat-square"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-B45309?style=flat-square"></a>
  <img alt="Platform" src="https://img.shields.io/badge/macOS%2026-Apple%20Silicon-1A1714?style=flat-square&logo=apple&logoColor=white">
  <a href="https://github.com/Aboudjem/Sleepless/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Aboudjem/Sleepless?style=flat-square&color=B45309"></a>
</p>

<p align="center">
  <img alt="Sleepless demo: flip the switch, set an auto-off timer, drag the battery-floor slider" src="assets/demo.gif" width="760">
</p>

> [!NOTE]
> Ein geschlossener Deckel schickt deinen Mac in den Ruhezustand, und `caffeinate`-Apps (KeepingYouAwake und Co.) können das von Haus aus nicht ändern. Sleepless legt die eine Einstellung um, die es kann, `pmset disablesleep`, mit Sicherheitsnetzen, sodass du es bedenkenlos vergessen kannst.

## Installation

```sh
brew install --cask aboudjem/tap/sleepless
/Applications/Sleepless.app/Contents/Resources/grant.sh   # one-time passwordless grant
```

| Weitere Wege | |
|---|---|
| **Herunterladen** | Hol dir das [latest release](https://github.com/Aboudjem/Sleepless/releases/latest), entpacke es nach `/Applications` und bestätige es dann unter **Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen** (es ist ad-hoc signiert). |
| **Aus dem Quellcode bauen** | `git clone https://github.com/Aboudjem/Sleepless.git && cd Sleepless && ./install.sh` (kein Gatekeeper-Hinweis). |

Klicke dann auf die Tasse in der Menüleiste, lege den Schalter um und schließe den Deckel.

## Funktionen

| | | |
|---|---|---|
| ☕ | **Ein Schalter** | Klicke auf die Tasse in der Menüleiste, lege den Schalter um. |
| ⏲️ | **Abschalt-Timer** | 1 h oder 2 h mit laufendem Countdown, danach aus. |
| 🔋 | **Akku-Mindeststand** | Auto-Abschaltung bei 5–50 % im Akkubetrieb (Standard 15 %). |
| 🪫 | **Low Power Mode** | Tritt zur Seite, wenn LPM im Akkubetrieb aktiv ist. |
| 🖥️ | **Kein Dongle** | Deckel geschlossen, im Akkubetrieb. Kein Monitor, kein HDMI-Stecker. |
| 🚀 | **Beim Anmelden starten** | Optional, standardmäßig aus, startet immer ausgeschaltet. |
| 🪶 | **Winzig und nativ** | Eine AppKit-Datei. Kein Dock-Symbol, kein Daemon, keine kext. |

**Menüleisten-Glyph:** leere Tasse = aus · volle Tasse = wach · volle Tasse mit Punkt = wach im Akkubetrieb (Auto-Abschaltung aktiv).

## Sleepless im Vergleich zu den Alternativen

| | **Sleepless** | Amphetamine | KeepingYouAwake | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| Wach, Deckel geschlossen, kein Monitor | ✅ ¹ | ⚠️ ² | ❌ ³ | ❌ |
| Im Akkubetrieb | ✅ | ✅ | ✅ Deckel offen | ⚠️ ⁴ |
| Abschalt-Timer | ✅ | ✅ | ✅ | ❌ |
| Auto-Abschaltung bei niedrigem Akku | ✅ | ✅ | ✅ | ❌ |
| Open Source | ✅ MIT | ❌ App Store | ✅ MIT | Apple |
| Kosten | Kostenlos | Kostenlos | Kostenlos | Kostenlos |

<sub>Stand 2026-06. ¹ Nutzt `pmset disablesleep` und liest das Flag zurück; das Verhalten hängt von Hardware und macOS-Version ab. ² Dokumentiert einen Modus für geschlossenen Bildschirm, versagt aber Berichten zufolge häufig auf Apple Silicon bei Wechsel der Stromquelle ([AE #28](https://github.com/x74353/Amphetamine-Enhancer/issues/28)); die App ist Closed Source. ³ Kann konzeptbedingt nicht bei geschlossenem Deckel arbeiten, da es `caffeinate` umhüllt ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). ⁴ `caffeinate -i` läuft im Akkubetrieb; `-s` nur am Netzteil.</sub>

## Setze es ein, um

- 🤖 Lange Jobs bei geschlossenem Deckel zu Ende zu bringen: Agenten-Läufe, Builds, Renders, ML-Training.
- 📡 Einen Hotspot aus deiner Tasche zu teilen.
- ⬇️ Große Downloads, Uploads oder Backups weiterlaufen zu lassen.
- 🖥️ Einen lokalen Server oder eine SSH-Sitzung erreichbar zu halten.

> [!TIP]
> Setze einen Akku-Mindeststand, dem du vertraust (etwa 20 %), plus einen Timer, dann kannst du weggehen, ohne den Akku im Auge behalten zu müssen.

## So funktioniert es

Sleepless schaltet `pmset disablesleep` um (das `SleepDisabled`-Flag des Kernels), liest es zurück, sodass die Menüleiste nie lügt, und setzt es bei deinem Akku-Mindeststand, im Low Power Mode, beim Ablaufen des Timers oder beim Neustart zurück. Eine GUI-App kann kein Passwort eintippen, deshalb fügt das Installationsprogramm eine eng gefasste sudoers-Regel für **genau zwei Befehle** hinzu:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Lässt sich nicht ausweiten.** sudoers gleicht Argumente wörtlich ab, ohne Platzhalter.
- **Nichts zum Kapern.** Kein Daemon, kein Hilfsskript, keine Shell. Es ruft `/usr/bin/pmset` direkt auf.
- **Immer reversibel.** Neustart, der Mindeststand, der Timer oder `./uninstall.sh` (das belegt, dass die Berechtigung weg ist).

Einen Download überprüfen, kein Apple-Konto nötig:

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Sleepless-*.zip -R Aboudjem/Sleepless
```

Vollständiges Bedrohungsmodell, das Urteil zum App Store und die Audit-Anleitung: [SECURITY.md](SECURITY.md) · [docs/AUDIT.md](docs/AUDIT.md).

## FAQ

<details>
<summary><b>Funktioniert <code>pmset disablesleep</code> auf Apple Silicon (M1/M2/M3) noch?</b></summary>

Ja, auf macOS 26.3 bestätigt. `pmset -a disablesleep 1` setzt das `SleepDisabled`-Flag des Kernels auf Apple Silicon und hält den Mac bei geschlossenem Deckel im Akkubetrieb wach. Prüfe es mit `pmset -g | grep SleepDisabled` (es sollte `1` anzeigen). Behauptungen, es habe "aufgehört zu funktionieren", beschreiben meist `caffeinate` oder Apps auf caffeinate-Basis, einen anderen Mechanismus.
</details>

<details>
<summary><b>Warum geht mein Mac beim Schließen des Deckels in den Ruhezustand, sogar mit Amphetamine oder KeepingYouAwake?</b></summary>

Diese nutzen die Power Assertions von macOS, die den Leerlauf-Timer stoppen, aber den Hardware-Trigger beim Schließen des Deckels nicht überstimmen können. KeepingYouAwake umhüllt `caffeinate`, das nicht bei geschlossenem Deckel arbeiten kann ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). `pmset disablesleep`, das Sleepless nutzt, kann es.
</details>

<details>
<summary><b>Ist es sicher? Überhitzt es oder zieht es den Akku leer?</b></summary>

Für leichte, unbeaufsichtigte Arbeit (Downloads, Synchronisierungen, einen Hotspot) ist es sicher. Schwere Dauerlast bei ganz geschlossenem Deckel verringert den Luftstrom, geh also mit Augenmaß vor. Der Akku-Mindeststand, die Auto-Abschaltung im Low Power Mode und der Timer stoppen es alle, bevor es den Mac leerzieht.
</details>

<details>
<summary><b>Braucht es sudo, eine Kernel-Erweiterung oder einen Daemon?</b></summary>

Eine eng gefasste `sudo`-Berechtigung (zwei exakte `pmset`-Befehle), damit eine GUI-App die Einstellung ohne Abfrage umlegen kann. Keine Kernel-Erweiterung, kein Daemon. Die ganze App ist eine einzige AppKit-Datei.
</details>

<details>
<summary><b>Wie stoppe oder entferne ich es?</b></summary>

Leg den Schalter auf aus, oder lass den Timer oder den Akku-Mindeststand abschalten, und der normale Ruhezustand kehrt zurück. Ein Neustart setzt es ebenfalls zurück. `./uninstall.sh` entfernt die App, den Anmelde-Eintrag und die sudoers-Berechtigung und belegt dann, dass die Berechtigung weg ist.
</details>

<details>
<summary><b>Warum ist es nicht notarisiert?</b></summary>

Es ist ein persönliches, quelloffenes Werkzeug ohne bezahlte Apple Developer ID, also ist es ad-hoc signiert. Baue es aus dem Quellcode, um Gatekeeper zu umgehen, oder nutze **Trotzdem öffnen** für die vorgefertigte App. Die Notarisierungsschritte sind in [docs/AUDIT.md](docs/AUDIT.md) dokumentiert.
</details>

## Mitwirken

Issues und PRs sind willkommen, besonders Übersetzungen und Berichte von anderer Hardware. Siehe [CONTRIBUTING.md](CONTRIBUTING.md) und den [Code of Conduct](CODE_OF_CONDUCT.md). Sleepless bleibt bewusst klein.

## Lizenz

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Wenn Sleepless dir einen Ausflug ins Terminal erspart hat, hilft ein ⭐ anderen, es zu finden.</sub>
</p>
