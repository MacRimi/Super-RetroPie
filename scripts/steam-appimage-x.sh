#!/bin/bash

# Define el directorio base del usuario estándar
HOME_DIR=$(eval echo ~$SUDO_USER)

# Define mkRomDir para crear directorios si no está ya definido
mkRomDir() {
    mkdir -p "$1"
}

# Actualiza el sistema con permisos de administrador
sudo apt-get update && sudo apt-get upgrade -y

# Añade soporte para arquitectura i386 si no está ya añadido
if ! dpkg --print-architecture | grep -q "i386"; then
    sudo dpkg --add-architecture i386
fi

# Instalar dependencias necesarias para Steam
REQUIRED_PACKAGES=(
    "libc6:amd64" "libc6:i386"
    "libegl1:amd64" "libegl1:i386"
    "libgbm1:amd64" "libgbm1:i386"
    "libgl1-mesa-glx:amd64" "libgl1-mesa-glx:i386"
    "libgl1-mesa-dri:amd64" "libgl1-mesa-dri:i386"
    "steam-libs-amd64:amd64" "steam-libs-i386:i386"
)

# Instalar las dependencias solo si no están ya instaladas
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "$pkg"; then
        sudo apt-get install -y "$pkg"
    fi
done

# Crear el directorio para instalar Steam si no existe
mkRomDir "$HOME_DIR/RetroPie/roms/steam"

# Crear el directorio "ajustes" si no existe
mkRomDir "$HOME_DIR/RetroPie/roms/ajustes"

# Descargar e instalar Steam solo si no está ya instalado
if [[ ! -f "$HOME_DIR/RetroPie/roms/steam/steam.deb" ]]; then
    wget --content-disposition "https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb" -O "$HOME_DIR/RetroPie/roms/steam/steam.deb"
fi

if ! which steam > /dev/null; then
    sudo apt-get install -y "$HOME_DIR/RetroPie/roms/steam/steam.deb"
    rm "$HOME_DIR/RetroPie/roms/steam/steam.deb"  # Eliminar el archivo después de instalar
fi

# Lista de rutas comunes para es_systems.cfg
ES_SYSTEMS_PATHS=(
    "/etc/emulationstation/es_systems.cfg"
    "/opt/retropie/configs/all/emulationstation/es_systems.cfg"
)

# Variable para almacenar la ruta correcta
ES_SYSTEMS_CFG=""

# Buscar la ruta correcta para es_systems.cfg
for path in "${ES_SYSTEMS_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        ES_SYSTEMS_CFG="$path"
        break
    fi
done

# Verificar si se encontró es_systems.cfg
if [[ -z "$ES_SYSTEMS_CFG" ]]; then
    echo "No se encontró es_systems.cfg. No se pueden agregar sistemas."
    exit 1
fi

# Añadir sistemas a es_systems.cfg
# Agregar el sistema "ajustes" antes de </systemList> solo si no está ya configurado
if ! grep -q '<name>ajustes</name>' "$ES_SYSTEMS_CFG"; then
    sudo sed -i "/<\/systemList>/i \
<system>\
    <name>ajustes</name>\
    <fullname>Configuraciones</fullname>\
    <path>$HOME_DIR/RetroPie/roms/ajustes</path>\
    <extension>.sh</extension>\
    <command>%ROM%</command>\
    <platform>config</platform>\
    <theme>ajustes</theme>\
</system>" "$ES_SYSTEMS_CFG"
fi

# Agregar el sistema "steam" antes de </systemList> solo si no está ya configurado
if ! grep -q '<name>steam</name>' "$ES_SYSTEMS_CFG"; then
    sudo sed -i "/<\/systemList>/i \
<system>\
    <name>steam</name>\
    <fullname>Steam</fullname>\
    <path>$HOME_DIR/RetroPie/roms/steam</path>\
    <extension>.sh</extension>\
    <command>%ROM%</command>\
    <platform>pc</platform>\
    <theme>steam</theme>\
</system>" "$ES_SYSTEMS_CFG"
fi

# Agregar script para lanzar Steam al directorio "ajustes" solo si no existe
if [[ ! -f "$HOME_DIR/RetroPie/roms/ajustes/lanzar_steam.sh" ]]; then
    cat <<EOF > "$HOME_DIR/RetroPie/roms/ajustes/lanzar_steam.sh"
#!/bin/bash
steam -noverifyfiles -bigpicture
wait
emulationstation
EOF

    chmod +x "$HOME_DIR/RetroPie/roms/ajustes/lanzar_steam.sh"
fi


# Agregar script para importar juegos de Steam al directorio "ajustes" solo si no existe
if [[ ! -f "$HOME_DIR/RetroPie/roms/ajustes/importar_juegos_steam.sh" ]]; then
    cat <<'EOF' > "$HOME_DIR/RetroPie/roms/ajustes/importar_juegos_steam.sh"
#!/usr/bin/env bash

# ##############################################################################
# Encuentra juegos de Steam en tu directorio de Steam y escribe scripts de shell para lanzar los juegos.
# ##############################################################################

# Configuración
readonly ROMS_DIR="${HOME}/RetroPie/roms/steam"
readonly OUTPUT_DIR="${ROMS_DIR}"

# Steam stuff"
readonly STEAM_APPS_DIR="${HOME}/.local/share/Steam/steamapps"
readonly STEAM_MANIFEST_EXT='.acf'

# ##############################################################################
# Obtiene la propiedad especificada del manifiesto de la aplicación de Steam.
#
# Argumentos:
#   app_manifest_path: la ruta completa al archivo de manifiesto de la aplicación.
#   property_name: el nombre de la propiedad que se desea obtener.
# ##############################################################################


function getManifestProperty() {
    local app_manifest_path="$1"
    local property_name="$2"

    # Utiliza grep y sed para extraer el valor de la propiedad del archivo de manifiesto
    grep "${property_name}" "${app_manifest_path}" | cut -d '"' -f 4 
}

# ##############################################################################
# Escribe el contenido de un script de shell para lanzar un juego de Steam.
#
# Argumentos:
#   app_id: el ID numérico para la aplicación de Steam.
#   app_name: el nombre de cadena de la aplicación de Steam.
# ##############################################################################

function shellScriptTemplate() {
    local app_id="$1"
    local app_name="$2"


cat <<EOF2
#!/bin/bash

# Lanza el juego desde Steam
steam -noverifyfiles  -bigpicture steam://rungameid/${app_id} &

# Esperar un poco para asegurarse de que el juego esté completamente cerrado antes de continuar
wait

# Una vez que el juego se cierra, cerrar Steam y reiniciar EmulationStation
emulationstation

EOF2
}


app_manifest_names=$(ls "${STEAM_APPS_DIR}" | grep "${STEAM_MANIFEST_EXT}")
for app_manifest_name in ${app_manifest_names}; do
    app_manifest_path="${STEAM_APPS_DIR}/${app_manifest_name}"
    app_id=$(getManifestProperty "${app_manifest_path}" '"appid"')
    app_name=$(getManifestProperty "${app_manifest_path}" '"name"')
    sanitized_app_name=$(echo "${app_name}" | sed 's/&/and/g' | tr ' ' '_')
    shell_script_path="${OUTPUT_DIR}/${sanitized_app_name}.sh"
    shell_script_contents=$(shellScriptTemplate "${app_id}" "${app_name}")

    echo "${shell_script_contents}" > "${shell_script_path}"
    chmod +x "${shell_script_path}"
  
done

emulationstation --quit  # Cerrar EmulationStation
emulationstation         # Reiniciar EmulationStation

EOF

    chmod +x "$HOME_DIR/RetroPie/roms/ajustes/importar_juegos_steam.sh"
fi

echo "Configuración completada. Por favor, reinicie EmulationStation para aplicar los cambios."
