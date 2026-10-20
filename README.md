Immutable Fedora desktop distrobox preparation:
`sudo dnf install mesa-libGL-devel libX11-devel libXrandr-devel libXinerama-devel libXi-devel libXcursor-devel`

Immutable Fedora desktop distrobox build CLion run config:
`distrobox-enter -T -n raylib-dev -- zig build -Doptimize=debug -Dstrip=false`