# RDPConnect

App nativa de macOS (AppKit) para administrar perfiles de conexión RDP y lanzarlos con [FreeRDP](https://www.freerdp.com/), con verificación del estado de [Tailscale](https://tailscale.com/) antes de conectar.

## Requisitos

- macOS 13.0+
- [FreeRDP](https://www.freerdp.com/) (`brew install freerdp`) — se busca el binario `sdl-freerdp` en `/opt/homebrew/bin` o `/usr/local/bin`.
- [Tailscale](https://tailscale.com/) (opcional) — si está instalado, la app avisa si no hay conexión VPN activa antes de conectar.

## Build

```bash
./build.sh
```

Compila los fuentes de `Sources/` con `swiftc` y genera `RDPConnect.app` en la raíz del proyecto.

## Uso

1. Abrí `RDPConnect.app`.
2. Creá un perfil con el botón "+" en la barra lateral.
3. Completá host, puerto, usuario y contraseña.
4. Click en "Conectar".

## Estructura

```
Sources/
  AppDelegate.swift            # ventana principal, split view, flujo de conexión
  SidebarViewController.swift  # lista de perfiles
  DetailViewController.swift   # formulario de edición de un perfil
  Profile.swift                # modelo de perfil y armado de argumentos RDP
  ProfileStore.swift           # persistencia en Application Support/RDPConnect/profiles.json
  RDPLauncher.swift            # lanza sdl-freerdp con los argumentos del perfil
  TailscaleStatus.swift        # chequea `tailscale status --json`
```

## Estado conocido / pendientes

- Las contraseñas se guardan en texto plano en `profiles.json` y se pasan como argumento de línea de comandos a `sdl-freerdp` (visibles vía `ps`). Migrar a Keychain y a `/from-stdin` de FreeRDP es la mejora de seguridad prioritaria.
- Sin firma de código ni notarización.
- Sin menú principal (`NSMenu`), por lo que atajos estándar de macOS como `Cmd+Q` no están disponibles.
- Sin tests automatizados.