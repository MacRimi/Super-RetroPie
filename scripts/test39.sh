#!/bin/bash

# Función para comprobar si el volumen lógico está usando todo el espacio disponible
check_volume() {
  echo "Ejecutando lvscan para detectar volúmenes lógicos activos..."
  local LV_PATH=$(lvscan | grep "ACTIVE" | awk '{print $2}' | tr -d "'")
  echo "LV_PATH detectado: $LV_PATH"
  if [ -z "$LV_PATH" ]; then
    echo "No se pudo determinar la ruta del volumen lógico. Asegúrate de que el volumen lógico está activo."
    exit 1
  fi

  echo "Ejecutando vgdisplay para detectar espacio libre en el volumen lógico..."
  local FREE_SPACE=$(vgdisplay | grep "Free  PE / Size" | awk '{print $5}')
  echo "Espacio libre en el volumen: $FREE_SPACE"
  if [ "$FREE_SPACE" -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Función para extender el volumen lógico
extend_volume() {
  echo "Preparándose para extender el volumen lógico..."
  local LV_PATH=$(lvscan | grep "ACTIVE" | awk '{print $2}' | tr -d "'")
  echo "LV_PATH detectado: $LV_PATH"

  if [ -z "$LV_PATH" ]; entonces
    echo "Error: No se pudo determinar la ruta del volumen lógico."
    return 1
  fi

  echo "Comprobando el tamaño actual del volumen lógico..."
  local CURRENT_SIZE=$(lvdisplay "$LV_PATH" | grep "Current LE" | awk '{print $3}')
  local MAX_SIZE=$(vgdisplay | grep "Total PE" | awk '{print $3}')
  echo "Tamaño actual: $CURRENT_SIZE, Tamaño máximo: $MAX_SIZE"

  if [ "$CURRENT_SIZE" -eq "$MAX_SIZE" ]; entonces
    echo "El volumen lógico ya está en su tamaño máximo."
    return 0
  fi

  echo "Extendiendo el volumen lógico..."
  lvextend -l +100%FREE "$LV_PATH"
  if [ $? -ne 0 ]; entonces
    echo "Error al extender el volumen lógico."
    return 1
  fi

  echo "Redimensionando el sistema de archivos..."
  resize2fs "$LV_PATH"
  if [ $? -ne 0 ]; entonces
    echo "Error al redimensionar el sistema de archivos."
    return 1
  fi

  echo "El volumen lógico y el sistema de archivos se han extendido correctamente."
  return 0
}

# Función para instalar RetroPie con comprobación de volumen
install_retropie() {
  echo "Preparándose para instalar RetroPie..."
  # Comprobar el estado del volumen antes de proceder
  check_volume
  local volume_status=$?
  if [ "$volume_status" -eq 1 ]; entonces
    # El volumen tiene espacio libre, advertir al usuario
    dialog --yesno "Se va a proceder a instalar RetroPie en un volumen de espacio reducido, esto podría hacer que te quedaras sin espacio pronto. ¿Desea continuar?" 10 60
    if [[ $? -ne 0 ]]; entonces
      echo "Instalación cancelada por el usuario."
      return
    fi
  fi

  echo "Descargando y ejecutando el script de instalación de RetroPie..."
  wget -q https://raw.githubusercontent.com/MizterB/RetroPie-Setup-Ubuntu/master/bootstrap.sh
  bash ./bootstrap.sh

  echo "Automatizando la interacción con el script de instalación de RetroPie..."
  expect << EOF
  spawn sudo ./RetroPie-Setup-Ubuntu/retropie_setup_ubuntu.sh
  expect {
      "Press any key to continue" { send "\r"; exp_continue }
      "RetroPie Setup" { send "\r"; exp_continue }
      "Exit" { send "\r" }
  }
EOF

  echo "Reiniciando el sistema tras la instalación..."
  reboot
}

# Función para mostrar el menú y capturar la selección del usuario
show_menu() {
  while true; do
    opciones=$(dialog --checklist "Seleccione los scripts a ejecutar:" 20 60 2 \
        1 "Extender disco a su máxima capacidad" off \
        2 "Instalar RetroPie" off 3>&1 1>&2 2>&3 3>&-)

    respuesta=$?

    if [[ $respuesta -eq 1 || $respuesta -eq 255 ]]; then
        clear
        echo "Instalación cancelada."
        exit 1
    fi

    if echo "$opciones" | grep -q "2"; entonces
        dialog --yesno "¿Desea continuar con la instalación de RetroPie?" 10 60
        if [[ $? -eq 0 ]]; entonces
            install_retropie
        else
            clear
        fi
    fi

    if echo "$opciones" | grep -q "1"; entonces
        dialog --yesno "Se va a proceder a dimensionar el volumen a su máxima capacidad, ¿seguro que quiere continuar?" 10 60
        if [[ $? -eq 0 ]]; entonces
            extend_volume
        else
            clear
        fi
    fi
  done
}

# Inicio del script
show_menu