### Sdl wrapper:
 
1. `distrobox create --name sdl-dev --image registry.fedoraproject.org/fedora-toolbox:44`
2. `sudo dnf install gcc gcc-c++ make cmake pkgconf-pkg-config wayland-devel wayland-protocols-devel libxkbcommon-devel libdecor-devel mesa-libEGL-devel mesa-libGL-devel alsa-lib-devel`
3. `distrobox-enter -T -n sdl-dev -- zig build -Doptimize=debug -Dstrip=false`

### Raylib wrapper:

1. `distrobox create --name raylib-dev --image registry.fedoraproject.org/fedora-toolbox:44`
2. `sudo dnf install mesa-libGL-devel libX11-devel libXrandr-devel libXinerama-devel libXi-devel libXcursor-devel`
3. `distrobox-enter -T -n raylib-dev -- zig build -Doptimize=debug -Dstrip=false`
