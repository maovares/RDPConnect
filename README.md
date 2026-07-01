# RDPConnect

App nativa de macOS (AppKit) para administrar perfiles de conexión RDP y lanzarlos con [FreeRDP](https://www.freerdp.com/), con verificación del estado de [Tailscale](https://tailscale.com/) antes de conectar.

## Requisitos

- macOS 13.0+
- [FreeRDP](https://www.freerdp.com/) (`brew install freerdp`) — se busca el binario `sdl-freerdp` primero en `$PATH` y después en `/opt/homebrew/bin` o `/usr/local/bin`. Probado contra FreeRDP 3.27.1.
- [Tailscale](https://tailscale.com/) (opcional) — si está instalado, la app chequea cada 5s si está corriendo y avisa si no antes de conectar.

## Build

```bash
./build.sh
```

Compila los fuentes de `Sources/` con `swiftc`, copia `Resources/` (ícono) y genera `RDPConnect.app` en la raíz del proyecto.

## Uso

1. Abrí `RDPConnect.app`.
2. Creá un perfil con el botón "+" en la barra lateral (el botón "⋯" da acceso a Duplicar/Eliminar con click izquierdo; también hay menú contextual con click derecho).
3. Completá host, puerto, usuario y contraseña. El botón Conectar se habilita solo cuando host/puerto son válidos.
4. "Guardar" fuerza el guardado inmediato (además, los cambios se autoguardan con un pequeño debounce). "Conectar" lanza `sdl-freerdp`.
5. Menú Archivo → Exportar/Importar perfiles (JSON, sin contraseñas).

## Estructura

```
Sources/
  AppDelegate.swift            # ventana principal, menú, flujo de conexión, monitoreo de Tailscale
  SidebarViewController.swift  # lista de perfiles, agregar/duplicar/eliminar
  DetailViewController.swift   # formulario de edición de un perfil
  Profile.swift                # modelo de perfil, validación y armado de argumentos RDP
  ProfileStore.swift           # persistencia (profiles.json + Keychain), debounce de guardado
  RDPLauncher.swift            # lanza sdl-freerdp (contraseña vía /args-from:env:, no en argv)
  TailscaleStatus.swift        # chequea `tailscale status --json`
  KeychainStore.swift          # wrapper de Keychain para las contraseñas
  BinaryLocator.swift          # búsqueda de binarios en $PATH + rutas conocidas
```

## Seguridad

- Las contraseñas se guardan en el **Keychain** de macOS (no en `profiles.json`, que solo tiene metadata).
- Al conectar, los argumentos de `sdl-freerdp` (incluida la contraseña) se pasan por una variable de entorno vía `/args-from:env:`, no como argumento directo — así no quedan visibles en `ps aux`. (Se evaluó `/from-stdin`, pero tiene un bug conocido en FreeRDP 3.x que rompe la negociación NLA.)
- Como la app no está firmada con una identidad estable, macOS puede volver a pedir acceso al Keychain en cada recompilación.

## Estado conocido / pendientes

- Sin firma de código ni notarización.
- Sin tests automatizados.
- El heurístico que detecta "falló la conexión" (proceso termina con error en <3s) puede dar falsos negativos si el servidor tarda en rechazar la conexión.
