### Sdl wrapper:
 
1. `distrobox create --name sdl-dev --image registry.fedoraproject.org/fedora-toolbox:44`
2. `sudo dnf install gcc gcc-c++ make cmake pkgconf-pkg-config wayland-devel wayland-protocols-devel libxkbcommon-devel libdecor-devel mesa-libEGL-devel mesa-libGL-devel alsa-lib-devel freetype-devel libXcursor-devel libXinerama-devel libXi-devel libXrandr-devel libXrender-devel libXfixes-devel libXdamage-devel libXcomposite-devel libXext-devel libX11-common libXScrnSaver-devel libXxf86vm-devel libXv-devel libXaw-devel libXtst-devel pipewire-jack-audio-connection-kit-devel`
3. `distrobox-enter -T -n sdl-dev -- zig build -Doptimize=debug -Dstrip=false`

### Raylib wrapper:

1. `distrobox create --name raylib-dev --image registry.fedoraproject.org/fedora-toolbox:44`
2. `sudo dnf install mesa-libGL-devel libX11-devel libXrandr-devel libXinerama-devel libXi-devel libXcursor-devel`
3. `distrobox-enter -T -n raylib-dev -- zig build -Doptimize=debug -Dstrip=false`
