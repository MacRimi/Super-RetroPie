#!/bin/sh

# Define constants and variables
APP=steam
APPIMAGETOOL_URL="https://api.github.com/repos/probonopd/go-appimage/releases"
PKG2APPIMAGE_URL="https://raw.githubusercontent.com/ivan-hc/AM-application-manager/main/tools/pkg2appimage"
TMP_DIR=tmp
RECIPE_FILE=recipe.yml

# Function to display error messages
show_error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to download files
download_file() {
    URL=$1
    FILENAME=$2

    wget -q "$URL" -O "$FILENAME" || show_error "Failed to download $FILENAME from $URL"
}

# Function to check if a file exists
file_exists() {
    FILE=$1
    test -f "$FILE"
}

# Create a temporary directory and navigate to it
mkdir -p "$TMP_DIR" || show_error "Failed to create temporary directory"
cd "$TMP_DIR" || show_error "Failed to change to temporary directory"

# Download appimagetool if it doesn't exist
if ! file_exists ./appimagetool; then
    echo "Downloading appimagetool..."
    DOWNLOAD_URL=$(wget -q "$APPIMAGETOOL_URL" -O - | grep -v zsync | grep -i continuous | grep -i appimagetool | grep -i x86_64 | grep browser_download_url | cut -d '"' -f 4 | head -1)
    download_file "$DOWNLOAD_URL" appimagetool
else
    echo "appimagetool already exists"
fi

# Download pkg2appimage if it doesn't exist
if ! file_exists ./pkg2appimage; then
    echo "Downloading pkg2appimage..."
    download_file "$PKG2APPIMAGE_URL" pkg2appimage
else
    echo "pkg2appimage already exists"
fi

# Grant execution permissions to the tools
chmod a+x ./appimagetool ./pkg2appimage || show_error "Failed to set execution permissions"

# Remove recipe file if it exists
file_exists "./$RECIPE_FILE" && rm -f "./$RECIPE_FILE"

# Create the recipe file
cat << EOF > "$RECIPE_FILE"
app: $APP
binpatch: true

ingredients:
  dist: stable
  script:
    - wget https://cdn.akamai.steamstatic.com/client/installer/steam.deb
  sources:
    - deb http://ftp.debian.org/debian/ stable main contrib non-free
  packages:
    - steam
    - coreutils
    - curl
    - grep
    - libc6-i386
    - python3
    - sed
    - steam-libs
    - tar
    - util-linux
    - xz-utils
    - zenity
    - zenity-common
EOF

# Create the custom AppRun file
rm -R -f "./$APP/$APP.AppDir/AppRun"
cat << 'EOF' > "./$APP/$APP.AppDir/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD=/:"${HERE}"
#export LD_PRELOAD="${HERE}"/libunionpreload.so
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:"${HERE}"/usr/bin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"
export LD_LIBRARY_PATH=/lib/:/lib64/:/lib/x86_64-linux-gnu/:/usr/lib/:"${HERE}"/usr/lib/:"${HERE}"/usr/lib/i386-linux-gnu/:"${HERE}"/usr/lib/x86_64-linux-gnu/:"${HERE}"/lib/:"${HERE}"/lib32/:"${HERE}"/lib/i386-linux-gnu/:"${HERE}"/usr/lib32/:"${HERE}"/lib/x86_64-linux-gnu/:"${LD_LIBRARY_PATH}"
export PYTHONPATH="${HERE}"/usr/share/pyshared/:"${HERE}"/usr/lib/python*/:"${PYTHONPATH}"
export PYTHONHOME="${HERE}"/usr/:"${HERE}"/usr/lib/python*/
export XDG_DATA_DIRS="${HERE}"/usr/share/:"${HERE}"/usr/share/steam/:"${XDG_DATA_DIRS}"
export PERLLIB="${HERE}"/usr/share/perl5/:"${HERE}"/usr/lib/perl5/:"${PERLLIB}"
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"
export QT_PLUGIN_PATH="${HERE}"/usr/lib/qt4/plugins/:"${HERE}"/usr/lib/steam/:"${HERE}"/usr/lib64/steam/:"${HERE}"/usr/lib32/steam/:"${HERE}"/usr/lib/i386-linux-gnu/qt4/plugins/:"${HERE}"/usr/lib/x86_64-linux-gnu/qt4/plugins/:"${HERE}"/usr/lib32/qt4/plugins/:"${HERE}"/usr/lib64/qt4/plugins/:"${HERE}"/usr/lib/qt5/plugins/:"${HERE}"/usr/lib/i386-linux-gnu/qt5/plugins/:"${HERE}"/usr/lib/x86_64-linux-gnu/qt5/plugins/:"${HERE}"/usr/lib32/qt5/plugins/:"${HERE}"/usr/lib64/qt5/plugins/:"${QT_PLUGIN_PATH}"
EOF

# Export the AppDir to an AppImage
ARCH=x86_64 VERSION=$(./appimagetool -v | grep -o '[[:digit:]]*') ./appimagetool -s "./$APP/$APP.AppDir" > /dev/null 2>&1

# Return to the previous directory
cd ..

# Move the resulting AppImage file
mv "./$TMP_DIR"/*.AppImage ./"$APP.AppImage"

echo "Steam has been packaged as $APP.AppImage"