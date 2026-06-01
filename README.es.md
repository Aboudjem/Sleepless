<!-- Language switcher. Keep this row identical across every README.<lang>.md. -->
<p align="center">
  <a href="README.md">English</a> &nbsp;·&nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp;·&nbsp;
  <b>Español</b> &nbsp;·&nbsp;
  <a href="README.ja.md">日本語</a> &nbsp;·&nbsp;
  <a href="README.fr.md">Français</a> &nbsp;·&nbsp;
  <a href="README.de.md">Deutsch</a>
</p>

> Esta traducción es generada por la comunidad o de forma automática y puede ir por detrás del README en inglés. La versión en inglés es la versión de referencia. Consulta el [README en inglés](README.md).

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img alt="Sleepless: keep your Mac awake with the lid closed" src="assets/hero-light.svg" width="760">
  </picture>
</p>

<p align="center">
  <b>Mantén tu MacBook despierta con la tapa cerrada, con batería y sin pantalla externa.</b><br>
  Un interruptor nativo en la barra de menús. Un apagado automático por nivel mínimo de batería para que nunca la sobrecalientes.
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

## Qué hace

Cierras la tapa de tu MacBook y se duerme. Eso suele ser lo que quieres, pero no cuando una
compilación nocturna, una descarga larga, la ejecución de un agente o una zona Wi-Fi personal necesitan seguir funcionando
mientras el portátil va en tu bolsa.

**Sleepless** es una pequeña app de la barra de menús que activa el único ajuste del sistema que realmente mantiene
despierto un Mac con la tapa cerrada, `pmset disablesleep`, y luego lo protege con un
**apagado automático por nivel mínimo de batería** para que un estado "encendido" olvidado no pueda agotar la batería ni acumular calor.

- 🌙 **Un interruptor nativo.** Haz clic en la luna de la barra de menús y cambia el conmutador. El glifo muestra
  el estado de un vistazo: `moon` hueca (apagado), `moon.fill` rellena (encendido), `moon.stars.fill` (armado:
  despierto con batería, apagado automático activo).
- 🔋 **Apagado automático por nivel mínimo de batería.** Arrastra un control deslizante (5–50 %, 15 % por defecto). Mientras está despierto y
  descargándose, Sleepless se apaga solo cuando llegas a ese mínimo.
- 🖥️ **Sin pantalla externa, sin adaptador de corriente, sin adaptador falso.** Solo la tapa cerrada, con batería.
- 🪶 **Nativo y diminuto.** AppKit + SF Symbols, sin icono en el Dock, sin dependencias de terceros, sin
  demonio en segundo plano, sin kext. Toda la app es un único `App.swift`.
- 🔍 **Honesto sobre el estado.** Vuelve a leer el valor real del sistema después de cada cambio, de modo que el
  interruptor refleja la realidad, nunca una suposición optimista.

## Instalación

### Homebrew (recomendado)

```sh
brew install --cask aboudjem/tap/sleepless
```

Eso añade el tap `Aboudjem/homebrew-tap` e instala `Sleepless.app`. Luego ejecuta la concesión única
(incluida dentro de la app) para que pueda cambiar el modo de reposo sin pedir contraseña. Imprime exactamente
lo que escribe antes de preguntar:

```sh
/Applications/Sleepless.app/Contents/Resources/grant.sh
```

### Descargar la versión publicada

Descarga `Sleepless-1.0.0.zip` desde [**Releases**](https://github.com/Aboudjem/Sleepless/releases/latest),
descomprímelo y mueve `Sleepless.app` a `/Applications`. Como tiene una firma ad-hoc (no está
notarizada), Gatekeeper de macOS bloqueará el primer arranque: abre **Ajustes del Sistema → Privacidad y
seguridad → Abrir igualmente**. (En macOS 15+ el viejo truco de clic derecho → Abrir ya no funciona.)

### Compilar desde el código fuente (sin aviso de Gatekeeper)

El modelo de confianza es "lee el código y compílalo tú mismo." Las apps compiladas localmente no quedan
en cuarentena, así que simplemente se ejecutan.

```sh
git clone https://github.com/Aboudjem/Sleepless.git
cd Sleepless
./install.sh        # builds, installs to /Applications, adds the grant + login item
```

`./build.sh` por sí solo solo produce `build/Sleepless.app` (solo Command Line Tools, sin Xcode).
`./uninstall.sh` elimina todo y demuestra que la concesión ha desaparecido.

## Por qué existe Sleepless

`caffeinate` de Apple (y cualquier app de la barra de menús construida sobre él, como KeepingYouAwake) **no puede**
mantener despierto un Mac con la tapa cerrada. Las aserciones de energía de IOKit que usa no anulan el
disparador de reposo por cierre de tapa del hardware, así que cerrar la tapa duerme el Mac de todas formas. La única
palanca del sistema que anula el reposo por cierre de tapa es `pmset disablesleep`.

Unas pocas herramientas sí recurren a `disablesleep`, pero cada una deja un hueco: Amphetamine lo hace (y mucho
más) pero su ruta de pantalla cerrada es famosamente caprichosa en Apple Silicon; Macchiato usa el
mecanismo exacto pero **no** incluye ninguna protección de batería; Clapet solo se activa cuando hay una **pantalla
externa** conectada. Sleepless es la herramienta de código abierto creada específicamente para el caso sencillo:
**tapa cerrada, con batería, sin pantalla, con un apagado automático para que sea seguro olvidarse de ella.**

## Comparación

| | **Sleepless** | Amphetamine | KeepingYouAwake | Macchiato | Clapet | `caffeinate` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Despierto, tapa cerrada, con batería | ✅ | ✅¹ | ❌ (rechazado) | ✅ | ⚠️ necesita pantalla ext. | ❌ |
| No necesita pantalla externa | ✅ | ✅ | n/a | ✅ | ❌ | n/a |
| Apagado automático por nivel mínimo de batería | ✅ | finaliza sesión con batería baja | ✅ (pero sin tapa cerrada) | ❌ | ❌ | ❌ |
| Mecanismo | `pmset disablesleep` + sudoers acotado | API pública ≈ `disablesleep` + IOKit | `caffeinate` | `pmset disablesleep` + helper | `pmset` + sudoers | aserción IOKit |
| Código abierto | ✅ MIT | ❌ (App Store) | ✅ MIT | ✅ Apache-2.0 | ✅ GPL-3.0 | Integrado en Apple |
| Estrellas | nuevo | App Store | ~6.6k | ~18 | ~101 | n/d |

<sub>¹ Amphetamine lo admite pero, en Apple Silicon, depende de un script "Power
Protect" instalado por separado y se informa ampliamente de que falla al conectar/desconectar la corriente y en configuraciones de KVM/dock. Los recuentos de estrellas se obtuvieron el 2026-06-01 y varían con el tiempo. Toda afirmación sobre la competencia está documentada
en las notas de investigación; se agradecen las correcciones.</sub>

## Casos de uso

Cada uno se combina con el nivel mínimo de batería: fija un mínimo con el que te sientas cómodo y olvídate.

- **Deja que un trabajo largo termine después de irte.** La ejecución de un agente/Claude, un render, una compilación, entrenamiento de
  ML, una gran instalación de `brew`/`npm`: enciende Sleepless, cierra la tapa, mételo en tu bolsa,
  y sigue funcionando.
- **Pasea compartiendo tu zona Wi-Fi.** La Zona Wi-Fi personal / Compartir Internet desde el Mac sigue
  activa con la tapa cerrada.
- **Transferencias desatendidas.** Descargas o subidas grandes, o una copia de Time Machine / respaldo que necesita
  completarse mientras te alejas.
- **Mantén accesible un servidor o sesión SSH.** Un servidor de desarrollo local, una sesión SSH o un demonio de sincronización
  siguen vivos con la tapa cerrada.
- **Mantén el audio en marcha.** La música, una emisión larga o un render de audio siguen reproduciéndose en la bolsa.

## Modelo de seguridad

Sleepless solicita una porción reducida de root, así que aquí está exactamente lo que es. El modelo de amenazas
completo está en [SECURITY.md](SECURITY.md).

Una app con interfaz gráfica no tiene una terminal en la que escribir una contraseña, así que `install.sh` escribe un archivo
`/etc/sudoers.d` estrictamente acotado (propiedad de `root:wheel`, modo `0440`), con tu nombre de usuario sustituido:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- **Permite exactamente dos comandos y nada más.** sudoers compara los argumentos literalmente y
  esta regla no tiene comodines, así que `sudo pmset -a sleep 0`, `pmset restoredefaults` o cualquier otro
  vector se descarta y exige una contraseña. La concesión no se puede ampliar.
- **Sin shell, sin script auxiliar.** La app llama a `sudo` con un array argv (sin `/bin/sh -c`), y
  la regla apunta directamente al `/usr/bin/pmset` de Apple. No hay ningún script con permisos de escritura para el usuario que un
  atacante pueda reescribir.
- **`disablesleep` no está documentado pero es real.** No está en `man pmset`, pero activa el indicador
  `SleepDisabled` del kernel (`pmset -g | grep SleepDisabled`). Como no está documentado, Apple podría
  cambiarlo; Sleepless vuelve a leer el valor después de cada cambio.
- **Un reinicio lo restablece a `0`.** Es un indicador en tiempo de ejecución, así que no hay forma de dejar tu Mac
  permanentemente incapaz de dormir. El nivel mínimo de batería es una segunda red de seguridad.
- **Riesgo residual honesto:** la concesión es sin contraseña por diseño, así que cualquier proceso que se ejecute como tú
  podría cambiar el indicador. En el peor de los casos es "tu Mac se mantuvo despierto, o se le permitió dormir," no pérdida de datos
  ni ejecución de código como root.
- **Desinstalación limpia.** `./uninstall.sh` elimina la app, el elemento de inicio de sesión y la concesión, y luego
  demuestra la revocación mostrando que `sudo -n pmset …` vuelve a pedir contraseña.

## Preguntas frecuentes

**¿De verdad mantiene el Mac despierto con la tapa cerrada, con batería y sin pantalla?**
Sí, ese es el objetivo entero. Verificado en macOS 26 (Tahoe) / Apple Silicon.

**La luna no aparece en mi barra de menús.** macOS 26 puede ocultar elementos de la barra de menús. Revisa Ajustes
del Sistema (ajustes de Centro de Control / Barra de menús) y asegúrate de que Sleepless tenga permiso para mostrar su
elemento; la app está en ejecución si `pgrep -x Sleepless` imprime un número.

**¿Por qué no está notarizada?** Es una herramienta personal de código abierto sin un Apple Developer ID de pago,
así que tiene una firma ad-hoc. Compila desde el código fuente para saltarte Gatekeeper por completo, o usa el flujo de **Abrir igualmente**
para la app precompilada. De todos modos, la notarización no es una garantía contra el malware.

**¿Agotará mi batería?** Solo si ignoras el mínimo. Mientras está despierto y descargándose,
Sleepless se apaga al porcentaje de batería que fijes (15 % por defecto), y un reinicio siempre
restaura el reposo normal.

**¿Funciona en Macs Intel o en macOS más antiguos?** Está verificado en **macOS 26 Apple Silicon**.
`disablesleep` no está documentado, así que el comportamiento en otras versiones/hardware no está garantizado. Pruébalo
y cuéntanoslo; se agradecen los informes honestos.

**¿Cómo lo elimino por completo?** `./uninstall.sh` (o borra `/Applications/Sleepless.app`,
elimina `/etc/sudoers.d/sleepless-disablesleep` con `sudo rm`, y haz `launchctl bootout` del
elemento de inicio de sesión).

## Cómo contribuir

Se agradecen las incidencias y los PR, en especial traducciones e informes de pruebas honestos desde otro
hardware/versiones de macOS. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) y el
[Código de conducta](CODE_OF_CONDUCT.md). Sleepless se mantiene deliberadamente pequeño: es poco probable que aterricen
funciones que amplíen la superficie de privilegios.

## Licencia

[MIT](LICENSE) © 2026 Adam Boudjemaa.

---

<p align="center">
  <sub>Si Sleepless te ahorró un viaje a la Terminal, una ⭐ ayuda a que otras personas lo encuentren.</sub>
</p>

