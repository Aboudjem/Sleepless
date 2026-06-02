<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <b>Français</b> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> Cette traduction est générée par la communauté ou par une machine et peut être en retard sur le README en anglais. La version anglaise fait foi. [English README](README.md).

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Sleepless garde votre MacBook éveillé capot fermé, sur batterie, sans écran externe.</b><br>
  <sub>Un seul interrupteur natif dans la barre des menus, avec une extinction automatique au niveau de batterie de votre choix pour ne jamais la vider complètement.</sub>
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
> Fermer le capot met normalement votre Mac en veille, et les applications basées sur `caffeinate` (KeepingYouAwake et consorts) **ne peuvent pas** changer cela. Sleepless bascule le seul réglage qui le permet, `pmset disablesleep`, puis le protège avec une extinction automatique au plancher de batterie, de sorte que vous pouvez l'oublier en toute sécurité.

## Ce que vous obtenez

|  |  |
|---|---|
| 🌙 **Un seul interrupteur** | Cliquez sur la lune dans la barre des menus, activez la bascule. Le glyphe indique l'état d'un coup d'œil. |
| 🔋 **Extinction automatique au plancher de batterie** | Choisissez un plancher (5 à 50 %, par défaut 15 %). Sur batterie, l'application se désactive d'elle-même avant que vous ne soyez à plat. |
| 🖥️ **Pas d'écran, pas de dongle** | Juste le capot fermé, sur batterie. Pas de moniteur externe, pas de fiche HDMI factice. |
| 🪶 **Minuscule et native** | AppKit + SF Symbols. Pas d'icône dans le Dock, pas de démon en arrière-plan, pas de kext, pas de dépendances. |

## Installation

**Homebrew** (recommandé) :

```sh
brew install --cask aboudjem/tap/sleepless
# one-time: add the passwordless grant (it prints exactly what it writes first)
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

**Compiler depuis les sources** (la voie de la confiance : lisez-le, compilez-le, sans invite Gatekeeper) :

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless && ./install.sh
```

**Ou téléchargez l'application :** récupérez la [dernière version](https://github.com/Aboudjem/Sleepless/releases/latest), décompressez-la et déplacez `Sleepless.app` vers `/Applications`. Elle est signée de façon ad-hoc, alors approuvez le premier lancement dans **Réglages Système → Confidentialité et sécurité → Ouvrir quand même** (l'ancienne astuce du clic droit → Ouvrir a été supprimée dans macOS 15).

Cliquez ensuite sur la lune, activez l'interrupteur et fermez le capot. `./uninstall.sh` supprime tout et prouve que l'autorisation a disparu.

## Comment ça marche

`caffeinate` et les assertions d'alimentation qu'il utilise ne peuvent pas passer outre le déclencheur matériel de fermeture du capot, donc un capot fermé met toujours le Mac en veille. Le seul réglage système qui le contourne est `pmset disablesleep`. Sleepless le bascule depuis un interrupteur natif, relit la valeur en direct pour que l'interface ne mente jamais, et revient automatiquement à votre plancher de batterie. Un redémarrage le réinitialise également. [Modèle de sécurité complet →](SECURITY.md)

## Sleepless face aux alternatives

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Éveillé, capot fermé, sur batterie | ✅ | ✅¹ | ❌ | ✅ | ⚠️ écran ext. | ❌ |
| Aucun écran externe requis | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| Extinction automatique au plancher de batterie | ✅ | batterie faible uniquement | ✅² | ❌ | ❌ | ❌ |
| Open source | ✅ MIT | ❌ App Store | ✅ MIT | ✅ Apache | ✅ GPL | Apple |

<sub>¹ Amphetamine le fait, mais sur Apple Silicon il s'appuie sur un script « Power Protect » distinct et est largement signalé comme défaillant lors de changements d'alimentation ou de dock. &nbsp; ² KeepingYouAwake dispose d'un seuil de coupure de batterie mais, par conception, ne peut pas rester éveillé capot fermé. Nombres d'étoiles (≈6,6k / ≈18 / ≈101) relevés le 2026-06-01 ; corrections bienvenues.</sub>

## À utiliser pour…

- 🤖 **Terminer une longue tâche après votre départ.** Une exécution d'agent IA, une compilation, un rendu, un entraînement ML, une grosse installation `brew`/`npm` : activez-le, fermez le capot, glissez-le dans votre sac, et revenez à une tâche terminée.
- 📡 **Partager votre connexion en déplacement.** Le partage Internet / Point d'accès personnel depuis le Mac continue de servir capot fermé.
- ⬇️ **Laisser tourner de gros transferts.** De grands téléchargements, des envois ou une sauvegarde Time Machine se terminent pendant votre absence.
- 🖥️ **Garder un serveur ou une session SSH active.** Un serveur de dev local, un démon de synchronisation ou une session distante reste joignable, capot fermé.
- 🎧 **Continuer la lecture audio.** De la musique ou un long rendu continue de tourner dans le sac.

> [!TIP]
> Réglez le plancher de batterie à un niveau de confiance (disons 20 %) et vous pouvez faire tout ce qui précède sans surveiller la batterie.

## Est-ce sûr ?

Oui, et c'est conçu pour être vérifiable. Une application graphique ne peut pas saisir de mot de passe, donc l'installateur ajoute une règle `/etc/sudoers.d` au périmètre strict (propriété de root, `0440`) qui autorise **exactement deux commandes et rien d'autre** :

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Elle ne peut pas être élargie.** `sudoers` compare les arguments littéralement sans jokers, donc toute autre commande redemande un mot de passe.
- **Aucun démon, aucun script auxiliaire** qu'un attaquant pourrait détourner. Elle appelle directement le `/usr/bin/pmset` d'Apple avec un tableau argv (sans shell).
- **Toujours réversible.** Un redémarrage réinitialise le drapeau, le plancher de batterie le désactive, et `./uninstall.sh` supprime l'autorisation et le prouve.

Le modèle de menace complet, les preuves bien réelles (mais non documentées) de `disablesleep`, et le compromis sur la notarisation se trouvent dans **[SECURITY.md](SECURITY.md)**.

## FAQ

<details>
<summary><b>Fonctionne-t-il vraiment capot fermé, sur batterie, sans écran ?</b></summary>

Oui, c'est tout l'intérêt. Vérifié sur macOS 26 (Tahoe) / Apple Silicon.
</details>

<details>
<summary><b>La lune n'apparaît pas dans ma barre des menus.</b></summary>

macOS 26 peut masquer les éléments de la barre des menus. Vérifiez les Réglages Système (Centre de contrôle / Barre des menus) et autorisez Sleepless à afficher son élément. Confirmez qu'il tourne avec <code>pgrep -x Sleepless</code>.
</details>

<details>
<summary><b>Pourquoi n'est-il pas notarisé ?</b></summary>

C'est un outil personnel et open source sans identifiant Apple Developer payant, il est donc signé de façon ad-hoc. Compilez depuis les sources pour contourner entièrement Gatekeeper, ou utilisez le flux <b>Ouvrir quand même</b> pour l'application préfabriquée.
</details>

<details>
<summary><b>Va-t-il vider ma batterie ?</b></summary>

Seulement si vous ignorez le plancher. Pendant qu'il est éveillé et en décharge, il se désactive au pourcentage que vous avez défini (par défaut 15 %), et un redémarrage rétablit toujours la veille normale.
</details>

<details>
<summary><b>Fonctionne-t-il sur Intel ou sur d'anciennes versions de macOS ?</b></summary>

Il est vérifié sur <b>macOS 26 Apple Silicon</b>. <code>disablesleep</code> n'est pas documenté, donc les autres versions ou matériels ne sont pas garantis. Essayez-le et faites un retour, les rapports honnêtes sont les bienvenus.
</details>

## Contribuer

Les tickets et les PR sont les bienvenus, en particulier les traductions et les rapports de test depuis d'autres matériels. Consultez [CONTRIBUTING.md](CONTRIBUTING.md) et le [Code de conduite](CODE_OF_CONDUCT.md). Sleepless reste délibérément petit.

## Licence

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Si Sleepless vous a évité un détour par le Terminal, une ⭐ aide d'autres personnes à le trouver.</sub>
</p>
