<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <b>Español</b> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> Esta traducción es generada por la comunidad o de forma automática y puede estar desactualizada respecto al README en inglés. La versión en inglés es la autoritativa. Consulta el [README en inglés](README.md).

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.gif">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.gif">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.gif" width="780">
  </picture>
</p>

<p align="center">
  <b>Sleepless mantiene tu MacBook despierto con la tapa cerrada, con batería y sin pantalla externa.</b><br>
  <sub>Un único interruptor nativo en la barra de menús, con apagado automático en el nivel de batería que elijas para que nunca la agotes del todo.</sub>
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
> Cerrar la tapa normalmente pone tu Mac a dormir, y las apps basadas en `caffeinate` (KeepingYouAwake y similares) **no pueden** cambiar eso. Sleepless activa el único ajuste que sí puede, `pmset disablesleep`, y luego lo protege con un apagado automático por nivel mínimo de batería para que sea seguro olvidarse de él.

## Qué obtienes

|  |  |
|---|---|
| 🌙 **Un solo interruptor** | Haz clic en la luna en la barra de menús y activa el conmutador. El glifo muestra el estado de un vistazo. |
| 🔋 **Apagado automático por nivel mínimo de batería** | Elige un mínimo (5–50 %, predeterminado 15 %). Con batería, se apaga solo antes de que la agotes. |
| 🖥️ **Sin pantalla, sin adaptador** | Solo la tapa cerrada, con batería. Sin monitor externo, sin enchufe HDMI ficticio. |
| 🪶 **Diminuto y nativo** | AppKit + SF Symbols. Sin icono en el Dock, sin daemon en segundo plano, sin kext, sin dependencias. |

## Instalación

**Homebrew** (recomendado):

```sh
brew install --cask aboudjem/tap/sleepless
# one-time: add the passwordless grant (it prints exactly what it writes first)
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

**Compilar desde el código fuente** (la vía de confianza: léelo, compílalo, sin aviso de Gatekeeper):

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless && ./install.sh
```

**O descarga la app:** obtén la [última versión](https://github.com/Aboudjem/Sleepless/releases/latest), descomprímela y mueve `Sleepless.app` a `/Applications`. Está firmada de forma ad-hoc, así que aprueba el primer lanzamiento en **Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente** (el viejo truco de clic derecho → Abrir se eliminó en macOS 15).

Luego haz clic en la luna, activa el interruptor y cierra la tapa. `./uninstall.sh` elimina todo y demuestra que el permiso ha desaparecido.

## Cómo funciona

`caffeinate` y las aserciones de energía que utiliza no pueden anular el disparador por hardware del cierre de la tapa, así que una tapa cerrada siempre pone el Mac a dormir. El único ajuste del sistema que lo anula es `pmset disablesleep`. Sleepless lo activa desde un interruptor nativo, vuelve a leer el valor en vivo para que la interfaz nunca mienta, y se revierte automáticamente en tu nivel mínimo de batería. Un reinicio también lo restablece. [Modelo de seguridad completo →](SECURITY.md)

## Sleepless frente a las alternativas

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Despierto, tapa cerrada, con batería | ✅ | ✅¹ | ❌ | ✅ | ⚠️ pantalla ext. | ❌ |
| No requiere pantalla externa | ✅ | ✅ | n/d | ✅ | ❌ | n/d |
| Apagado automático por nivel mínimo de batería | ✅ | solo batería baja | ✅² | ❌ | ❌ | ❌ |
| Código abierto | ✅ MIT | ❌ App Store | ✅ MIT | ✅ Apache | ✅ GPL | Apple |

<sub>¹ Amphetamine lo hace, pero en Apple Silicon depende de un script aparte, "Power Protect", y se reporta ampliamente que falla con cambios de alimentación o de dock. &nbsp; ² KeepingYouAwake tiene un corte por batería pero, por diseño, no puede permanecer despierto con la tapa cerrada. Recuentos de estrellas (≈6.6k / ≈18 / ≈101) obtenidos el 2026-06-01; se agradecen correcciones.</sub>

## Úsalo para…

- 🤖 **Terminar un trabajo largo después de irte.** La ejecución de un agente de IA, una compilación, un render, entrenamiento de ML, una gran instalación de `brew`/`npm`: actívalo, cierra la tapa, métela en la mochila y vuelve a un trabajo terminado.
- 📡 **Compartir tu punto de acceso en movimiento.** Compartir Internet / Compartir conexión desde el Mac sigue funcionando con la tapa cerrada.
- ⬇️ **Dejar transferencias grandes en marcha.** Descargas o subidas grandes, o una copia de Time Machine, se completan mientras te alejas.
- 🖥️ **Mantener vivo un servidor o una sesión SSH.** Un servidor de desarrollo local, un daemon de sincronización o una sesión remota siguen accesibles con la tapa cerrada.
- 🎧 **Mantener el audio en marcha.** La música o un render largo sigue reproduciéndose dentro de la mochila.

> [!TIP]
> Fija el nivel mínimo de batería en un valor en el que confíes (digamos 20 %) y podrás hacer todo lo anterior sin tener que vigilar la batería.

## ¿Es seguro?

Sí, y está hecho para ser auditable. Una app con interfaz gráfica no puede escribir una contraseña, así que el instalador añade una regla `/etc/sudoers.d` de alcance muy reducido (propiedad de root, `0440`) que permite **exactamente dos comandos y nada más**:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **No se puede ampliar.** `sudoers` coincide con los argumentos de forma literal, sin comodines, así que cualquier otro comando vuelve a pedir una contraseña.
- **Sin daemon, sin script auxiliar** que un atacante pueda secuestrar. Llama directamente al `/usr/bin/pmset` de Apple con un array de argv (sin shell).
- **Siempre reversible.** Un reinicio restablece el indicador, el nivel mínimo de batería lo apaga, y `./uninstall.sh` elimina el permiso y lo demuestra.

El modelo de amenazas completo, la evidencia no documentada pero real de `disablesleep`, y el compromiso sobre la notarización están en **[SECURITY.md](SECURITY.md)**.

## Preguntas frecuentes

<details>
<summary><b>¿De verdad funciona con la tapa cerrada, con batería y sin pantalla?</b></summary>

Sí, esa es toda la idea. Verificado en macOS 26 (Tahoe) / Apple Silicon.
</details>

<details>
<summary><b>La luna no aparece en mi barra de menús.</b></summary>

macOS 26 puede ocultar elementos de la barra de menús. Revisa Ajustes del Sistema (Centro de Control / Barra de menús) y permite que Sleepless muestre su elemento. Confirma que está en ejecución con <code>pgrep -x Sleepless</code>.
</details>

<details>
<summary><b>¿Por qué no está notarizada?</b></summary>

Es una herramienta personal de código abierto sin un Apple Developer ID de pago, así que está firmada de forma ad-hoc. Compila desde el código fuente para saltarte Gatekeeper por completo, o usa el flujo <b>Abrir igualmente</b> para la app precompilada.
</details>

<details>
<summary><b>¿Agotará mi batería?</b></summary>

Solo si ignoras el nivel mínimo. Mientras está despierto y descargándose, se apaga en el porcentaje que fijes (predeterminado 15 %), y un reinicio siempre restablece el sueño normal.
</details>

<details>
<summary><b>¿Funciona en Intel o en versiones antiguas de macOS?</b></summary>

Está verificado en <b>macOS 26 Apple Silicon</b>. <code>disablesleep</code> no está documentado, así que no se garantiza en otras versiones o hardware. Pruébalo y cuéntanos, se agradecen los informes honestos.
</details>

## Cómo contribuir

Se agradecen issues y PRs, especialmente traducciones e informes de pruebas desde otro hardware. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) y el [Código de Conducta](CODE_OF_CONDUCT.md). Sleepless se mantiene deliberadamente pequeño.

## Licencia

[MIT](LICENSE) © 2026 Adam Boudjemaa.

<p align="center">
  <sub>Si Sleepless te ahorró un viaje al Terminal, una ⭐ ayuda a que otras personas lo encuentren.</sub>
</p>
