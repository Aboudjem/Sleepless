<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <a href="README.es.md">Español</a> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <b>Français</b> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> Cette traduction est générée par la communauté ou par une machine et peut être en retard sur le README anglais. La version anglaise fait foi. Voir le [README anglais](README.md).

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <b>Gardez votre MacBook éveillé capot fermé, sur batterie, sans écran externe.</b><br>
  Un seul interrupteur natif dans la barre des menus. Un arrêt automatique au seuil de batterie pour ne jamais malmener la batterie.
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

## Ce que ça fait

Fermez le capot de votre MacBook et il se met en veille. C'est généralement ce que vous voulez, mais pas quand une compilation nocturne, un long téléchargement, l'exécution d'un agent ou un partage de connexion personnel doivent continuer pendant que le portable est dans votre sac.

**Sleepless** est une petite application de barre des menus qui bascule le seul réglage système qui maintient réellement un Mac éveillé capot fermé, `pmset disablesleep`, puis le surveille avec un **arrêt automatique au seuil de batterie** pour qu'un état « activé » oublié ne puisse pas vider la batterie ni emprisonner la chaleur.

- 🌙 **Un seul interrupteur natif.** Cliquez sur la lune dans la barre des menus, basculez l'interrupteur. Le glyphe montre l'état d'un coup d'œil : `moon` creux (désactivé), `moon.fill` plein (activé), `moon.stars.fill` (armé : éveillé sur batterie, arrêt automatique actif).
- 🔋 **Arrêt automatique au seuil de batterie.** Faites glisser un curseur (5 à 50 %, valeur par défaut 15 %). Pendant qu'il est éveillé et en décharge, Sleepless se désactive de lui-même quand vous atteignez ce seuil.
- 🖥️ **Pas d'écran externe, pas d'adaptateur secteur, pas de dongle factice.** Juste le capot fermé, sur batterie.
- 🪶 **Natif et minuscule.** AppKit + SF Symbols, pas d'icône dans le Dock, aucune dépendance tierce, aucun démon en arrière-plan, aucun kext. Toute l'application tient dans un seul `App.swift`.
- 🔍 **Honnête sur son état.** Elle relit la valeur système en direct après chaque bascule, de sorte que l'interrupteur reflète la réalité, jamais une supposition optimiste.

## Installation

### Homebrew (recommandé)

```sh
brew install --cask aboudjem/tap/sleepless
```

Cela ajoute le tap `Aboudjem/homebrew-tap` et installe `Sleepless.app`. Lancez ensuite l'autorisation unique (incluse dans l'application) pour qu'elle puisse basculer la veille sans demande de mot de passe. Elle affiche exactement ce qu'elle écrit avant de demander :

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

### Télécharger la version publiée

Récupérez `Sleepless-1.0.0.zip` depuis les [**Releases**](https://github.com/Aboudjem/Sleepless/releases/latest), décompressez, et déplacez `Sleepless.app` vers `/Applications`. Comme elle est signée de manière ad hoc (non notarisée), Gatekeeper de macOS bloquera le premier lancement : ouvrez **Réglages Système → Confidentialité et sécurité → Ouvrir quand même**. (Sur macOS 15+, l'ancienne astuce du clic droit → Ouvrir ne fonctionne plus.)

### Compiler depuis les sources (sans invite Gatekeeper)

Le modèle de confiance est « lisez le code, compilez-le vous-même ». Les applications compilées localement ne sont pas mises en quarantaine, elles s'exécutent donc simplement.

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./install.sh        # builds, installs to /Applications, adds the grant + login item
```

`./build.sh` seul produit simplement `build/Sleepless.app` (Command Line Tools uniquement, pas besoin de Xcode). `./uninstall.sh` supprime tout et prouve que l'autorisation a disparu.

## Pourquoi Sleepless existe

Le `caffeinate` d'Apple (et toute application de barre des menus bâtie dessus, comme KeepingYouAwake) **ne peut pas** maintenir un Mac éveillé capot fermé. Les assertions d'alimentation IOKit qu'il utilise ne passent pas outre le déclencheur matériel de veille en clamshell, donc fermer le capot met le Mac en veille quoi qu'il arrive. Le seul levier système qui passe outre la veille en clamshell est `pmset disablesleep`.

Quelques outils recourent bien à `disablesleep`, mais chacun laisse une faille : Amphetamine le fait (et bien plus) mais son chemin écran fermé est notoirement capricieux sur Apple Silicon ; Macchiato emploie le mécanisme exact mais n'embarque **aucun** garde-fou de batterie ; Clapet ne se déclenche que lorsqu'un **écran externe** est connecté. Sleepless est l'outil open source dédié au cas simple : **capot fermé, sur batterie, sans écran, avec un arrêt automatique pour qu'on puisse l'oublier en toute sécurité.**

## Comparaison

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Éveillé, capot fermé, sur batterie | ✅ | ✅¹ | ❌ (refusé) | ✅ | ⚠️ nécessite un écran ext. | ❌ |
| Pas besoin d'écran externe | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| Arrêt automatique au seuil de batterie | ✅ | fin de session sur batterie faible | ✅ (mais pas capot fermé) | ❌ | ❌ | ❌ |
| Mécanisme | `pmset disablesleep` + sudoers restreint | API publique ≈ `disablesleep` + IOKit | `caffeinate` | `pmset disablesleep` + assistant | `pmset` + sudoers | assertion IOKit |
| Open source | ✅ MIT | ❌ (App Store) | ✅ MIT | ✅ Apache-2.0 | ✅ GPL-3.0 | intégré à Apple |
| Étoiles | nouveau | App Store | ~6,6k | ~18 | ~101 | s.o. |

<sub>¹ Amphetamine le prend en charge mais, sur Apple Silicon, repose sur un script « Power Protect » installé séparément et est largement signalé comme défaillant lors du branchement/débranchement de l'alimentation et avec les configurations KVM/dock. Les décomptes d'étoiles ont été relevés le 2026-06-01 et évoluent avec le temps. Chaque affirmation sur un concurrent est sourcée dans les notes de recherche ; les corrections sont bienvenues.</sub>

## Cas d'usage

Chacun se combine avec le seuil de batterie : fixez un seuil qui vous convient et partez.

- **Laissez une longue tâche se terminer après votre départ.** Une exécution d'agent/Claude, un rendu, une compilation, un entraînement ML, une grosse installation `brew`/`npm` : activez Sleepless, fermez le capot, glissez-le dans votre sac, ça continue de tourner.
- **Déplacez-vous en partageant votre connexion.** Le Partage de connexion / Partage Internet depuis le Mac reste actif capot fermé.
- **Transferts sans surveillance.** De gros téléchargements, des envois, ou une sauvegarde Time Machine qui doit se terminer pendant que vous vous absentez.
- **Gardez un serveur ou une session SSH accessible.** Un serveur de développement local, une session SSH ou un démon de synchronisation reste en vie capot fermé.
- **Gardez l'audio en marche.** De la musique, une longue diffusion ou un rendu audio continue de jouer dans le sac.

## Modèle de sécurité

Sleepless demande une fine tranche de droits root, voici donc exactement de quoi il s'agit. Le modèle de menace complet se trouve dans [SECURITY.md](SECURITY.md).

Une application graphique n'a pas de terminal où taper un mot de passe, donc `install.sh` écrit un fichier additionnel `/etc/sudoers.d` étroitement délimité (propriété `root:wheel`, mode `0440`), avec votre nom d'utilisateur substitué :

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Il autorise exactement deux commandes et rien d'autre.** sudoers compare les arguments littéralement et cette règle n'a aucun caractère générique, donc `sudo pmset -a sleep 0`, `pmset restoredefaults` ou tout autre vecteur passe au travers et exige un mot de passe. L'autorisation ne peut pas être élargie.
- **Aucun shell, aucun script d'assistance.** L'application appelle `sudo` avec un tableau argv (pas de `/bin/sh -c`), et la règle pointe directement vers le `/usr/bin/pmset` d'Apple. Il n'y a aucun script modifiable par l'utilisateur qu'un attaquant pourrait réécrire.
- **`disablesleep` n'est pas documenté mais bien réel.** Il n'est pas dans `man pmset`, mais il positionne le drapeau `SleepDisabled` du noyau (`pmset -g | grep SleepDisabled`). Comme il n'est pas documenté, Apple pourrait le changer ; Sleepless relit la valeur après chaque bascule.
- **Un redémarrage le remet à `0`.** C'est un drapeau d'exécution, il n'y a donc aucun moyen de rendre votre Mac définitivement incapable de se mettre en veille. Le seuil de batterie est un second filet de sécurité.
- **Risque résiduel assumé :** l'autorisation est sans mot de passe par conception, donc tout processus s'exécutant sous votre identité pourrait basculer le drapeau. Le pire cas est « votre Mac est resté éveillé, ou a été autorisé à dormir », pas une perte de données ni une exécution de code root.
- **Désinstallation propre.** `./uninstall.sh` supprime l'application, l'élément d'ouverture et l'autorisation, puis prouve la révocation en montrant que `sudo -n pmset …` redemande un mot de passe.

## FAQ

**Est-ce que ça maintient vraiment le Mac éveillé capot fermé, sur batterie, sans écran ?**
Oui, c'est tout l'intérêt. Vérifié sur macOS 26 (Tahoe) / Apple Silicon.

**La lune n'apparaît pas dans ma barre des menus.** macOS 26 peut masquer les éléments de la barre des menus. Vérifiez les Réglages Système (réglages du Centre de contrôle / de la barre des menus) et assurez-vous que Sleepless est autorisé à afficher son élément ; l'application tourne si `pgrep -x Sleepless` affiche un nombre.

**Pourquoi n'est-il pas notarisé ?** C'est un outil personnel et open source sans Apple Developer ID payant, il est donc signé de manière ad hoc. Compilez depuis les sources pour contourner entièrement Gatekeeper, ou utilisez le flux **Ouvrir quand même** pour l'application précompilée. La notarisation n'est de toute façon pas une garantie contre les logiciels malveillants.

**Va-t-il vider ma batterie ?** Seulement si vous ignorez le seuil. Pendant qu'il est éveillé et en décharge, Sleepless se désactive au pourcentage de batterie que vous avez fixé (valeur par défaut 15 %), et un redémarrage rétablit toujours la veille normale.

**Fonctionne-t-il sur les Mac Intel ou les versions plus anciennes de macOS ?** Il est vérifié sur **macOS 26 Apple Silicon**. `disablesleep` n'est pas documenté, donc le comportement sur d'autres versions/matériels n'est pas garanti. Essayez et faites-nous savoir ; les retours honnêtes sont bienvenus.

**Comment le supprimer complètement ?** `./uninstall.sh` (ou supprimez `/Applications/Sleepless.app`, retirez `/etc/sudoers.d/sleepless-disablesleep` avec `sudo rm`, et faites un `launchctl bootout` sur l'élément d'ouverture).

## Contribuer

Les issues et PR sont bienvenues, en particulier les traductions et les rapports de test honnêtes depuis d'autres matériels/versions de macOS. Voir [CONTRIBUTING.md](CONTRIBUTING.md) et le [Code de conduite](CODE_OF_CONDUCT.md). Sleepless reste délibérément petit : les fonctionnalités qui agrandissent la surface de privilèges ont peu de chances d'être intégrées.

## Licence

[MIT](LICENSE) © 2026 Adam Boudjemaa.

---

<p align="center">
  <sub>Si Sleepless vous a évité un détour par le Terminal, une ⭐ aide d'autres personnes à le trouver.</sub>
</p>
