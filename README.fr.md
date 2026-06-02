<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <b>Français</b> &nbsp;·&nbsp;
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
  <b>Gardez votre MacBook éveillé capot fermé, sur batterie, sans écran externe.</b><br>
  <sub>Un seul interrupteur dans la barre des menus, avec minuterie d'extinction automatique et coupure au plancher de batterie pour ne jamais la vider à plat.</sub>
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
> Capot fermé, votre Mac se met en veille, et les applis basées sur `caffeinate` (KeepingYouAwake et consorts) ne peuvent rien y changer, c'est voulu par conception. Sleepless bascule le seul réglage qui le peut, `pmset disablesleep`, avec des filets de sécurité pour que vous puissiez l'oublier sans risque.

## Installation

```sh
brew install --cask aboudjem/tap/sleepless
/Applications/Sleepless.app/Contents/Resources/grant.sh   # one-time passwordless grant
```

| Autres méthodes | |
|---|---|
| **Téléchargement** | Récupérez la [dernière version](https://github.com/Aboudjem/Sleepless/releases/latest), décompressez vers `/Applications`, puis approuvez-la dans **Réglages Système → Confidentialité et sécurité → Ouvrir quand même** (elle est signée de façon ad-hoc). |
| **Compiler depuis les sources** | `git clone https://github.com/Aboudjem/Sleepless.git && cd Sleepless && ./install.sh` (sans invite Gatekeeper). |

Cliquez ensuite sur la tasse dans la barre des menus, basculez l'interrupteur et fermez le capot.

## Fonctionnalités

| | | |
|---|---|---|
| ☕ | **Un seul interrupteur** | Cliquez sur la tasse dans la barre des menus, basculez l'interrupteur. |
| ⏲️ | **Minuterie d'extinction automatique** | 1 h ou 2 h avec compte à rebours en direct, puis extinction. |
| 🔋 | **Plancher de batterie** | Extinction automatique entre 5 et 50 % sur batterie (15 % par défaut). |
| 🪫 | **Mode Économie d'énergie** | S'efface quand le mode Économie d'énergie est actif, sur batterie. |
| 🖥️ | **Sans dongle** | Capot fermé, sur batterie. Sans moniteur, sans fiche HDMI. |
| 🚀 | **Lancer à l'ouverture de session** | Optionnel, désactivé par défaut, démarre toujours à l'arrêt. |
| 🪶 | **Minuscule et native** | Un seul fichier AppKit. Sans icône dans le Dock, démon ni kext. |

**Glyphe de la barre des menus :** tasse vide = arrêt · tasse pleine = éveillé · tasse pleine + point = éveillé sur batterie (extinction automatique active).

## Sleepless face aux alternatives

| | **Sleepless** | Amphetamine | KeepingYouAwake | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| Éveillé, capot fermé, sans moniteur | ✅ ¹ | ⚠️ ² | ❌ ³ | ❌ |
| Sur batterie | ✅ | ✅ | ✅ capot ouvert | ⚠️ ⁴ |
| Minuterie d'extinction automatique | ✅ | ✅ | ✅ | ❌ |
| Extinction automatique à batterie faible | ✅ | ✅ | ✅ | ❌ |
| Open source | ✅ MIT | ❌ App Store | ✅ MIT | Apple |
| Coût | Gratuit | Gratuit | Gratuit | Gratuit |

<sub>Au 2026-06. ¹ Utilise `pmset disablesleep` et relit le drapeau ; le comportement dépend du matériel et de la version de macOS. ² Documente le mode écran fermé mais est largement signalé comme défaillant sur Apple Silicon lors d'un changement de source d'alimentation ([AE #28](https://github.com/x74353/Amphetamine-Enhancer/issues/28)) ; l'application est propriétaire. ³ Ne peut pas maintenir le capot fermé par conception, il enveloppe `caffeinate` ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). ⁴ `caffeinate -i` tourne sur batterie ; `-s` est réservé au secteur.</sub>

## À utiliser pour

- 🤖 Terminer une tâche nocturne capot fermé : exécutions d'agents, compilations, rendus, entraînement ML.
- 📡 Partager un point d'accès depuis votre sac.
- ⬇️ Laisser tourner de gros téléchargements, envois ou sauvegardes.
- 🖥️ Garder un serveur local ou une session SSH joignable.

> [!TIP]
> Réglez un plancher de batterie de confiance (disons 20 %) plus une minuterie, et vous pouvez partir sans surveiller la batterie.

## Comment ça marche

Sleepless bascule `pmset disablesleep` (le drapeau `SleepDisabled` du noyau), le relit pour que la barre des menus ne mente jamais, et le rétablit à votre plancher de batterie, en mode Économie d'énergie, à la fin de la minuterie ou au redémarrage. Une application graphique ne peut pas saisir de mot de passe, alors l'installateur ajoute une règle sudoers au périmètre strict pour **exactement deux commandes** :

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Impossible à élargir.** sudoers compare les arguments littéralement, sans jokers.
- **Rien à détourner.** Pas de démon, pas de script auxiliaire, pas de shell. Elle appelle `/usr/bin/pmset` directement.
- **Toujours réversible.** Le redémarrage, le plancher, la minuterie ou `./uninstall.sh` (qui prouve que l'autorisation a disparu).

Vérifiez un téléchargement, sans compte Apple :

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Sleepless-*.zip -R Aboudjem/Sleepless
```

Le modèle de menace complet, le verdict sur l'App Store et le guide d'audit : [SECURITY.md](SECURITY.md) · [docs/AUDIT.md](docs/AUDIT.md).

## FAQ

<details>
<summary><b>Est-ce que <code>pmset disablesleep</code> fonctionne encore sur Apple Silicon (M1/M2/M3) ?</b></summary>

Oui, confirmé sur macOS 26.3. `pmset -a disablesleep 1` positionne le drapeau `SleepDisabled` du noyau sur Apple Silicon, ce qui garde le Mac éveillé capot fermé sur batterie. Vérifiez avec `pmset -g | grep SleepDisabled` (il doit afficher `1`). Les affirmations selon lesquelles cela « ne fonctionne plus » décrivent en général `caffeinate` ou les applis basées sur caffeinate, un mécanisme différent.
</details>

<details>
<summary><b>Pourquoi mon Mac se met-il en veille à la fermeture du capot, même avec Amphetamine ou KeepingYouAwake ?</b></summary>

Ces outils utilisent les assertions d'alimentation de macOS, qui arrêtent la minuterie d'inactivité mais ne peuvent pas passer outre le déclencheur matériel de fermeture du capot. KeepingYouAwake enveloppe `caffeinate`, qui ne peut pas maintenir le capot fermé ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). `pmset disablesleep`, que Sleepless utilise, le peut.
</details>

<details>
<summary><b>Est-ce sûr ? Va-t-il surchauffer ou vider la batterie ?</b></summary>

C'est sûr pour des tâches légères et sans surveillance (téléchargements, synchronisations, point d'accès). Une charge soutenue et intense capot complètement fermé réduit la circulation de l'air, alors faites preuve de jugement. Le plancher de batterie, l'extinction automatique en mode Économie d'énergie et la minuterie l'arrêtent tous avant qu'il ne vide le Mac.
</details>

<details>
<summary><b>A-t-il besoin de sudo, d'une extension noyau ou d'un démon ?</b></summary>

Une seule autorisation `sudo` au périmètre strict (deux commandes `pmset` exactes) pour qu'une application graphique puisse basculer le réglage sans invite. Pas d'extension noyau, pas de démon. Toute l'application tient dans un seul fichier AppKit.
</details>

<details>
<summary><b>Comment l'arrêter ou le supprimer ?</b></summary>

Désactivez l'interrupteur, ou laissez la minuterie ou le plancher de batterie le faire, et la veille normale revient. Un redémarrage le réinitialise aussi. `./uninstall.sh` supprime l'application, l'élément de connexion et l'autorisation sudoers, puis prouve que l'autorisation a disparu.
</details>

<details>
<summary><b>Pourquoi n'est-il pas notarisé ?</b></summary>

C'est un outil personnel et open source sans identifiant Apple Developer payant, il est donc signé de façon ad-hoc. Compilez depuis les sources pour contourner Gatekeeper, ou utilisez **Ouvrir quand même** pour l'application préfabriquée. Les étapes de notarisation sont documentées dans [docs/AUDIT.md](docs/AUDIT.md).
</details>

## Contribuer

Les tickets et les PR sont les bienvenus, en particulier les traductions et les rapports depuis d'autres matériels. Consultez [CONTRIBUTING.md](CONTRIBUTING.md) et le [Code de conduite](CODE_OF_CONDUCT.md). Sleepless reste délibérément petit.

## Licence

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Si Sleepless vous a évité un détour par le Terminal, une ⭐ aide d'autres personnes à le trouver.</sub>
</p>
