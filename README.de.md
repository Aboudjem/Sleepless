<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <b>Deutsch</b>
</p>

> Diese Übersetzung wurde von der Community bzw. maschinell erstellt und kann hinter der englischen README zurückliegen. Maßgeblich ist die englische Fassung. Siehe [English README](README.md).

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <b>Halte dein MacBook bei geschlossenem Deckel, im Akkubetrieb und ohne externes Display wach.</b><br>
  Ein nativer Menüleisten-Schalter. Eine Akku-Schwellen-Abschaltung, damit du den Akku nie überstrapazierst.
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

## Was es macht

Schließt du den Deckel deines MacBooks, geht es in den Ruhezustand. Das ist meistens genau das, was du willst, aber nicht, wenn ein nächtlicher Build, ein langer Download, ein Agent-Lauf oder ein persönlicher Hotspot weiterlaufen soll, während das Laptop in deiner Tasche steckt.

**Sleepless** ist eine winzige Menüleisten-App, die genau die eine Systemeinstellung umlegt, die einen Mac bei geschlossenem Deckel tatsächlich wach hält, `pmset disablesleep`, und sie dann mit einer automatischen **Akku-Schwellen-Abschaltung** absichert, damit ein vergessener "Ein"-Zustand weder den Akku leersaugt noch Hitze staut.

- 🌙 **Ein nativer Schalter.** Klick auf den Mond in der Menüleiste, leg den Schalter um. Die Glyphe zeigt den Zustand auf einen Blick: hohler `moon` (aus), gefüllter `moon.fill` (ein), `moon.stars.fill` (scharfgeschaltet: wach im Akkubetrieb, Abschaltung aktiv).
- 🔋 **Akku-Schwellen-Abschaltung.** Zieh an einem Regler (5–50 %, Standard 15 %). Während die App wach ist und der Akku sich entlädt, schaltet sich Sleepless selbst aus, sobald du diese Schwelle erreichst.
- 🖥️ **Kein externes Display, kein Netzteil, kein Dummy-Dongle.** Nur der geschlossene Deckel, im Akkubetrieb.
- 🪶 **Nativ und winzig.** AppKit + SF Symbols, kein Dock-Symbol, keine Drittanbieter-Abhängigkeiten, kein Hintergrund-Daemon, kein kext. Die ganze App besteht aus einer einzigen `App.swift`.
- 🔍 **Ehrlich beim Zustand.** Sie liest nach jedem Umschalten den aktuellen Systemwert zurück, sodass der Schalter die Realität widerspiegelt und nie eine hoffnungsvolle Annahme.

## Installation

### Homebrew (empfohlen)

```sh
brew install --cask aboudjem/tap/sleepless
```

Das tappt `Aboudjem/homebrew-tap` und installiert `Sleepless.app`. Führe danach die einmalige Berechtigungsvergabe aus (in der App gebündelt), damit sie den Ruhezustand ohne Passwortabfrage umschalten kann. Sie gibt genau aus, was sie schreibt, bevor sie nachfragt:

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

### Das Release herunterladen

Hol dir `Sleepless-1.0.0.zip` von den [**Releases**](https://github.com/Aboudjem/Sleepless/releases/latest), entpacke es und verschiebe `Sleepless.app` nach `/Applications`. Da die App ad-hoc signiert (nicht notarisiert) ist, blockiert macOS Gatekeeper den ersten Start: öffne **Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen**. (Auf macOS 15+ funktioniert der alte Trick mit Rechtsklick → Öffnen nicht mehr.)

### Aus dem Quellcode bauen (keine Gatekeeper-Abfrage)

Das Vertrauensmodell lautet "lies den Quellcode, bau ihn selbst". Lokal gebaute Apps werden nicht unter Quarantäne gestellt und laufen einfach.

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./install.sh        # builds, installs to /Applications, adds the grant + login item
```

`./build.sh` allein erzeugt nur `build/Sleepless.app` (nur Command Line Tools, kein Xcode). `./uninstall.sh` entfernt alles und weist nach, dass die Berechtigung verschwunden ist.

## Warum es Sleepless gibt

Apples `caffeinate` (und jede darauf aufbauende Menüleisten-App wie KeepingYouAwake) **kann** einen Mac bei geschlossenem Deckel **nicht** wach halten. Die IOKit-Power-Assertions, die es verwendet, setzen den hardwareseitigen Clamshell-Sleep-Trigger nicht außer Kraft, sodass das Schließen des Deckels den Mac ungeachtet dessen in den Ruhezustand schickt. Der einzige Systemhebel, der den Clamshell-Sleep außer Kraft setzt, ist `pmset disablesleep`.

Ein paar Tools greifen zu `disablesleep`, aber jedes lässt eine Lücke: Amphetamine kann es (und noch viel mehr), aber sein Pfad für das geschlossene Display ist auf Apple Silicon notorisch zickig; Macchiato nutzt genau den Mechanismus, liefert aber **keinen** Akkuschutz mit; Clapet greift nur, wenn ein **externes Display** angeschlossen ist. Sleepless ist das zweckgebaute Open-Source-Tool für den schlichten Fall: **Deckel zu, im Akkubetrieb, kein Display, mit einer Abschaltung, sodass man es gefahrlos vergessen kann.**

## Vergleich

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Wach, Deckel zu, im Akkubetrieb | ✅ | ✅¹ | ❌ (verweigert) | ✅ | ⚠️ braucht ext. Display | ❌ |
| Kein externes Display nötig | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| Akku-Schwellen-Abschaltung | ✅ | Sitzungsende bei niedrigem Akku | ✅ (aber nicht bei geschlossenem Deckel) | ❌ | ❌ | ❌ |
| Mechanismus | `pmset disablesleep` + eingegrenzte sudoers | öffentliche API ≈ `disablesleep` + IOKit | `caffeinate` | `pmset disablesleep` + Helfer | `pmset` + sudoers | IOKit-Assertion |
| Open Source | ✅ MIT | ❌ (App Store) | ✅ MIT | ✅ Apache-2.0 | ✅ GPL-3.0 | in Apple integriert |
| Sterne | neu | App Store | ~6,6k | ~18 | ~101 | n. v. |

<sub>¹ Amphetamine unterstützt es, setzt auf Apple Silicon aber auf ein separat installiertes "Power Protect"-Skript und bricht Berichten zufolge häufig beim Anschließen/Trennen der Stromversorgung sowie bei KVM-/Dock-Setups ab. Die Sternzahlen wurden am 2026-06-01 erhoben und verschieben sich im Laufe der Zeit. Jede Aussage über einen Mitbewerber ist in den Recherchenotizen belegt; Korrekturen sind willkommen.</sub>

## Anwendungsfälle

Jeder davon passt zur Akku-Schwelle: leg eine Schwelle fest, mit der du dich wohlfühlst, und geh weg.

- **Lass einen langen Job fertig werden, nachdem du gegangen bist.** Ein Agent-/Claude-Lauf, ein Render, ein Compile, ML-Training, eine große `brew`-/`npm`-Installation: schalt Sleepless ein, schließ den Deckel, leg es in deine Tasche, es läuft weiter.
- **Geh herum und teile deinen Hotspot.** Persönlicher Hotspot / Internetfreigabe vom Mac bleibt bei geschlossenem Deckel aktiv.
- **Unbeaufsichtigte Übertragungen.** Große Downloads, Uploads oder ein Time Machine-/Backup-Lauf, der abgeschlossen werden muss, während du dich entfernst.
- **Halte einen Server oder eine SSH-Sitzung erreichbar.** Ein lokaler Dev-Server, eine SSH-Sitzung oder ein Sync-Daemon bleibt bei geschlossenem Deckel am Leben.
- **Halte den Ton am Laufen.** Musik, ein langer Cast oder ein Audio-Render läuft in der Tasche weiter.

## Sicherheitsmodell

Sleepless bittet um ein schmales Stück Root-Rechte, also hier genau, worum es geht. Das vollständige Bedrohungsmodell steht in [SECURITY.md](SECURITY.md).

Eine GUI-App hat kein Terminal, in das man ein Passwort eingeben könnte, deshalb schreibt `install.sh` ein eng eingegrenztes `/etc/sudoers.d`-Drop-in (Eigentümer `root:wheel`, Modus `0440`), in das dein Benutzername eingesetzt wird:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Es erlaubt genau zwei Befehle und sonst nichts.** sudoers gleicht Argumente buchstäblich ab, und diese Regel hat keine Platzhalter, sodass `sudo pmset -a sleep 0`, `pmset restoredefaults` oder jeder andere Vektor durchfällt und ein Passwort verlangt. Die Berechtigung lässt sich nicht ausweiten.
- **Keine Shell, kein Helfer-Skript.** Die App ruft `sudo` mit einem argv-Array auf (kein `/bin/sh -c`), und die Regel zeigt direkt auf Apples `/usr/bin/pmset`. Es gibt kein vom Benutzer beschreibbares Skript, das ein Angreifer umschreiben könnte.
- **`disablesleep` ist undokumentiert, aber real.** Es steht nicht in `man pmset`, setzt aber das `SleepDisabled`-Flag des Kernels (`pmset -g | grep SleepDisabled`). Weil es undokumentiert ist, könnte Apple es ändern; Sleepless liest den Wert nach jedem Umschalten zurück.
- **Ein Neustart setzt es auf `0` zurück.** Es ist ein Laufzeit-Flag, also gibt es keine Möglichkeit, deinen Mac dauerhaft am Schlafen zu hindern. Die Akku-Schwelle ist ein zweites Sicherheitsnetz.
- **Ehrliches Restrisiko:** die Berechtigung ist von Haus aus passwortlos, sodass jeder Prozess, der unter deinem Benutzer läuft, das Flag umlegen könnte. Der schlimmste Fall ist "dein Mac wurde wach gehalten oder durfte schlafen", nicht Datenverlust oder Root-Codeausführung.
- **Saubere Deinstallation.** `./uninstall.sh` entfernt die App, das Login-Objekt und die Berechtigung und belegt den Entzug, indem es zeigt, dass `sudo -n pmset …` wieder nach einem Passwort fragt.

## FAQ

**Hält es den Mac wirklich bei geschlossenem Deckel, im Akkubetrieb und ohne Display wach?**
Ja, genau das ist der Sinn. Verifiziert auf macOS 26 (Tahoe) / Apple Silicon.

**Der Mond erscheint nicht in meiner Menüleiste.** macOS 26 kann Menüleisten-Objekte ausblenden. Prüfe die Systemeinstellungen (Kontrollzentrum / Menüleisten-Einstellungen) und stelle sicher, dass Sleepless sein Objekt anzeigen darf; die App läuft, wenn `pgrep -x Sleepless` eine Zahl ausgibt.

**Warum ist es nicht notarisiert?** Es ist ein persönliches Open-Source-Tool ohne kostenpflichtige Apple Developer ID, daher ist es ad-hoc signiert. Bau es aus dem Quellcode, um Gatekeeper ganz zu umgehen, oder nutze den **Trotzdem öffnen**-Ablauf für die vorgefertigte App. Notarisierung ist ohnehin keine Garantie gegen Schadsoftware.

**Saugt es meinen Akku leer?** Nur, wenn du die Schwelle ignorierst. Während die App wach ist und der Akku sich entlädt, schaltet sich Sleepless bei dem von dir eingestellten Akkustand (Standard 15 %) ab, und ein Neustart stellt immer den normalen Ruhezustand wieder her.

**Funktioniert es auf Intel-Macs oder älterem macOS?** Es ist auf **macOS 26 Apple Silicon** verifiziert. `disablesleep` ist undokumentiert, daher ist das Verhalten auf anderen Versionen/Hardware nicht garantiert. Probier es aus und sag uns Bescheid; ehrliche Berichte sind willkommen.

**Wie entferne ich es vollständig?** `./uninstall.sh` (oder lösche `/Applications/Sleepless.app`, entferne `/etc/sudoers.d/sleepless-disablesleep` mit `sudo rm` und führe `launchctl bootout` für das Login-Objekt aus).

## Mitwirken

Issues und PRs sind willkommen, besonders Übersetzungen und ehrliche Testberichte von anderer Hardware/macOS-Versionen. Siehe [CONTRIBUTING.md](CONTRIBUTING.md) und den [Verhaltenskodex](CODE_OF_CONDUCT.md). Sleepless bleibt bewusst klein: Features, die die Privilegienfläche vergrößern, werden vermutlich nicht aufgenommen.

## Lizenz

[MIT](LICENSE) © 2026 Adam Boudjemaa.

---

<p align="center">
  <sub>Wenn Sleepless dir einen Ausflug ins Terminal erspart hat, hilft ein ⭐ anderen, es zu finden.</sub>
</p>
