<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <b>Español</b> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
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
  <b>Mantén tu MacBook despierto con la tapa cerrada, con batería y sin pantalla externa.</b><br>
  <sub>Un interruptor en la barra de menús, con temporizador de apagado automático y corte por nivel mínimo de batería para que nunca la agotes del todo.</sub>
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
> Cerrar la tapa pone tu Mac a dormir, y las apps basadas en `caffeinate` (KeepingYouAwake y similares) no pueden evitarlo, por diseño. Sleepless activa el único ajuste que sí puede, `pmset disablesleep`, con redes de seguridad para que sea seguro olvidarse de él.

## Instalación

```sh
brew install --cask aboudjem/tap/sleepless
/Applications/Sleepless.app/Contents/Resources/grant.sh   # one-time passwordless grant
```

| Otras formas | |
|---|---|
| **Descargar** | Coge la [última versión](https://github.com/Aboudjem/Sleepless/releases/latest), descomprímela en `/Applications` y apruébala en **Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente** (está firmada de forma ad-hoc). |
| **Compilar desde el código** | `git clone https://github.com/Aboudjem/Sleepless.git && cd Sleepless && ./install.sh` (sin aviso de Gatekeeper). |

Luego haz clic en la taza de la barra de menús, activa el interruptor y cierra la tapa.

## Características

| | | |
|---|---|---|
| ☕ | **Un solo interruptor** | Haz clic en la taza de la barra de menús y activa el conmutador. |
| ⏲️ | **Temporizador de apagado** | 1 h o 2 h con cuenta atrás en vivo, y luego se apaga. |
| 🔋 | **Nivel mínimo de batería** | Apagado automático al 5–50 % con batería (15 % por defecto). |
| 🪫 | **Low Power Mode** | Se hace a un lado cuando LPM está activado, con batería. |
| 🖥️ | **Sin adaptador** | Tapa cerrada, con batería. Sin monitor, sin enchufe HDMI. |
| 🚀 | **Iniciar al iniciar sesión** | Opcional, desactivado por defecto, siempre arranca apagado. |
| 🪶 | **Diminuto y nativo** | Un archivo de AppKit. Sin icono en el Dock, daemon ni kext. |

**Glifo de la barra de menús:** taza vacía = apagado · taza llena = despierto · taza llena con punto = despierto con batería (apagado automático en vivo).

## Sleepless frente a las alternativas

| | **Sleepless** | Amphetamine | KeepingYouAwake | `caffeinate` |
|---|:---:|:---:|:---:|:---:|
| Despierto, tapa cerrada, sin monitor | ✅ ¹ | ⚠️ ² | ❌ ³ | ❌ |
| Con batería | ✅ | ✅ | ✅ lid open | ⚠️ ⁴ |
| Temporizador de apagado | ✅ | ✅ | ✅ | ❌ |
| Apagado automático con batería baja | ✅ | ✅ | ✅ | ❌ |
| Código abierto | ✅ MIT | ❌ App Store | ✅ MIT | Apple |
| Coste | Gratis | Gratis | Gratis | Gratis |

<sub>A fecha de 2026-06. ¹ Usa `pmset disablesleep` y vuelve a leer el indicador; el comportamiento depende del hardware y la versión de macOS. ² Documenta el modo de pantalla cerrada pero se reporta ampliamente que falla en Apple Silicon al cambiar la fuente de alimentación ([AE #28](https://github.com/x74353/Amphetamine-Enhancer/issues/28)); la app es de código cerrado. ³ No puede hacer tapa cerrada por diseño, envuelve `caffeinate` ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). ⁴ `caffeinate -i` funciona con batería; `-s` es solo con corriente.</sub>

## Úsalo para

- 🤖 Terminar trabajos nocturnos con la tapa cerrada: ejecuciones de agentes, compilaciones, renders, entrenamiento de ML.
- 📡 Compartir tu punto de acceso desde la mochila.
- ⬇️ Dejar en marcha descargas, subidas o copias de seguridad grandes.
- 🖥️ Mantener accesible un servidor local o una sesión SSH.

> [!TIP]
> Fija un nivel mínimo de batería en el que confíes (digamos 20 %) más un temporizador, y podrás alejarte sin tener que vigilar la batería.

## Cómo funciona

Sleepless activa `pmset disablesleep` (el indicador `SleepDisabled` del kernel), vuelve a leerlo para que la barra de menús nunca mienta, y lo revierte en tu nivel mínimo de batería, en Low Power Mode, cuando el temporizador termina o al reiniciar. Una app gráfica no puede escribir una contraseña, así que el instalador añade una regla de sudoers de alcance reducido para **exactamente dos comandos**:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **No se puede ampliar.** sudoers coincide con los argumentos de forma literal, sin comodines.
- **Nada que secuestrar.** Sin daemon, sin script auxiliar, sin shell. Llama directamente a `/usr/bin/pmset`.
- **Siempre reversible.** Un reinicio, el nivel mínimo, el temporizador o `./uninstall.sh` (que demuestra que el permiso ha desaparecido).

Verifica una descarga, sin necesidad de cuenta de Apple:

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Sleepless-*.zip -R Aboudjem/Sleepless
```

El modelo de amenazas completo, el veredicto sobre la App Store y la guía de auditoría: [SECURITY.md](SECURITY.md) · [docs/AUDIT.md](docs/AUDIT.md).

## Preguntas frecuentes

<details>
<summary><b>¿sigue funcionando <code>pmset disablesleep</code> en Apple Silicon (M1/M2/M3)?</b></summary>

Sí. `pmset -a disablesleep 1` activa el indicador `SleepDisabled` del kernel en Apple Silicon, confirmado de primera mano en macOS 26.3, lo que mantiene el Mac despierto con la tapa cerrada y con batería. Verifícalo con `pmset -g | grep SleepDisabled` (debería leerse `1`). Las afirmaciones de que "dejó de funcionar" suelen describir `caffeinate` o apps basadas en caffeinate, un mecanismo distinto.
</details>

<details>
<summary><b>¿por qué mi Mac se duerme al cerrar la tapa incluso con Amphetamine o KeepingYouAwake?</b></summary>

Esas usan aserciones de energía de macOS, que detienen el temporizador de inactividad pero no pueden anular el disparador por hardware del cierre de la tapa. KeepingYouAwake envuelve `caffeinate`, que no puede hacer tapa cerrada ([#66](https://github.com/newmarcel/KeepingYouAwake/issues/66)). `pmset disablesleep`, que es lo que usa Sleepless, sí puede.
</details>

<details>
<summary><b>¿es seguro? ¿se sobrecalentará o agotará la batería?</b></summary>

Es seguro para trabajo ligero y sin supervisión (descargas, sincronizaciones, un punto de acceso). Una carga sostenida y pesada con la tapa totalmente cerrada reduce el flujo de aire, así que usa el sentido común. El nivel mínimo de batería, el apagado automático en Low Power Mode y el temporizador lo detienen todos antes de que agote el Mac.
</details>

<details>
<summary><b>¿necesita sudo, una extensión de kernel o un daemon?</b></summary>

Un único permiso `sudo` de alcance reducido (dos comandos `pmset` exactos) para que una app gráfica pueda cambiar el ajuste sin un aviso. Sin extensión de kernel, sin daemon. Toda la app es un único archivo de AppKit.
</details>

<details>
<summary><b>¿cómo lo detengo o lo elimino?</b></summary>

Desactiva el interruptor, o deja que el temporizador o el nivel mínimo de batería lo hagan, y el sueño normal vuelve. Un reinicio también lo restablece. `./uninstall.sh` elimina la app, el elemento de inicio de sesión y el permiso de sudoers, y luego demuestra que el permiso ha desaparecido.
</details>

<details>
<summary><b>¿por qué no está notarizada?</b></summary>

Es una herramienta personal de código abierto sin un Apple Developer ID de pago, así que está firmada de forma ad-hoc. Compila desde el código fuente para saltarte Gatekeeper, o usa **Abrir igualmente** para la app precompilada. Los pasos de notarización están documentados en [docs/AUDIT.md](docs/AUDIT.md).
</details>

## Cómo contribuir

Se agradecen issues y PRs, especialmente traducciones e informes desde otro hardware. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) y el [Código de Conducta](CODE_OF_CONDUCT.md). Sleepless se mantiene deliberadamente pequeño.

## Licencia

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Si Sleepless te ahorró un viaje al Terminal, una ⭐ ayuda a que otras personas lo encuentren.</sub>
</p>
