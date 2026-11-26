#!/bin/bash

# Proyecto: Respaldo Seguro Linux
# Autor: Aaron
# Carrera: Ciberseguridad - V ciclo
# Version: 2.0
# Descripcion: Sistema interactivo de copias de seguridad.

set -o pipefail

# Establecer permisos restrictivos
umask 077

# Rutas principales del proyecto
BASE=$(cd "$(dirname "$0")/.." && pwd) || exit 1
ORIGEN="$BASE/datos"
DESTINO="$BASE/backups"
REGISTRO="$BASE/logs/backup.log"

# Colores para los mensajes
CELESTE='\033[1;36m'
VERDE='\033[1;32m'
ROJO='\033[1;31m'
AMARILLO='\033[1;33m'
NORMAL='\033[0m'

# Crear las carpetas necesarias
if ! mkdir -p "$DESTINO" "$BASE/logs"; then
    echo "ERROR: No se pudieron crear las carpetas"
    exit 1
fi

DESTINO=$(realpath -- "$DESTINO") || exit 1

# Funcion para registrar los eventos
registrar() {
    printf '%s | %s\n' "$(date '+%F %T')" "$1" |
        tee -a "$REGISTRO"
}

# Funcion para crear copias de seguridad
crear_respaldo() {

    local carpeta="$1"
    local archivo nombre fecha contenido

    # Validar que la carpeta exista
    if [ ! -d "$carpeta" ]; then
        registrar "ERROR: La carpeta no existe"
        return 1
    fi

    carpeta=$(realpath -- "$carpeta") || return 1

    # Evitar respaldar la raiz o el propio destino
    if [[ "$carpeta" == / ||
          "$DESTINO/" == "$carpeta/"* ||
          "$carpeta/" == "$DESTINO/"* ]]; then

        registrar "ERROR: Ruta no permitida"
        return 1
    fi

    # Validar permisos de acceso
    if [ ! -r "$carpeta" ] || [ ! -x "$carpeta" ]; then
        registrar "ERROR: Permisos insuficientes"
        return 1
    fi

    # Comprobar que la carpeta tenga contenido
    contenido=$(find "$carpeta" -mindepth 1 \
        -maxdepth 1 -print -quit) || return 1

    if [ -z "$contenido" ]; then
        registrar "ERROR: La carpeta esta vacia"
        return 1
    fi

    # Obtener nombre y fecha del respaldo
    nombre=$(basename "$carpeta")
    fecha=$(date +%Y%m%d_%H%M%S)

    # Crear un archivo con nombre unico
    archivo=$(mktemp \
        "$DESTINO/respaldo_${nombre}_${fecha}_XXXXXX.tar.gz") || return 1

    echo -e "${CELESTE}Iniciando copia de seguridad...${NORMAL}"
    echo -e "${VERDE}[CORRECTO] Carpeta validada${NORMAL}"

    # Comprimir archivos y generar huella digital
    if tar -czf "$archivo" \
        -C "$(dirname "$carpeta")" -- "$nombre" &&
        sha256sum "$archivo" > "$archivo.sha256"; then

        echo -e "${VERDE}[CORRECTO] Respaldo generado${NORMAL}"
        echo -e "${VERDE}[CORRECTO] Huella SHA-256 creada${NORMAL}"

        if ! registrar "EXITO: $(basename "$archivo")"; then
            echo -e "${ROJO}No se pudo guardar el registro${NORMAL}"
            return 1
        fi

        echo -e "${VERDE}Proceso finalizado correctamente${NORMAL}"
        echo "Archivo: $(basename "$archivo")"

        return 0

    else

        # Eliminar archivos incompletos
        if ! rm -f -- "$archivo" "$archivo.sha256"; then
            registrar "ERROR: No se pudieron eliminar los archivos incompletos"
        fi

        registrar "ERROR: Fallo durante el respaldo"

        echo -e "${ROJO}No se pudo completar la copia de seguridad${NORMAL}"

        return 1
    fi
}

# Funcion para consultar el contenido de un respaldo
consultar_respaldo() {

    local seleccion
    local archivos=("$DESTINO"/*.tar.gz)

    if [ "${#archivos[@]}" -eq 0 ]; then
        echo "No existen respaldos disponibles"
        return
    fi

    PS3="Seleccione un respaldo: "

    select seleccion in "${archivos[@]##*/}" "Volver"; do

        if [ "$seleccion" = "Volver" ]; then
            break
        fi

        if [ -n "$seleccion" ]; then

            echo "Contenido del respaldo:"

            if ! tar -tzf "$DESTINO/$seleccion"; then
                registrar "ERROR: No se pudo leer el respaldo"
                return 1
            fi

            break
        fi

        echo "Seleccione un numero valido"

    done
}

# Funcion para consultar el historial
consultar_historial() {

    echo -e "${CELESTE}HISTORIAL DE OPERACIONES${NORMAL}"

    if [ -f "$REGISTRO" ]; then
        cat "$REGISTRO"
    else
        echo "No existen registros disponibles"
    fi
}

# Funcion para mostrar permisos y huellas digitales
consultar_seguridad() {

    echo -e "${CELESTE}PERMISOS DE SEGURIDAD${NORMAL}"
    ls -l "$DESTINO"

    echo ""
    echo -e "${CELESTE}HUELLAS DIGITALES SHA-256${NORMAL}"

    local huellas=("$DESTINO"/*.sha256)

    if [ "${#huellas[@]}" -gt 0 ]; then
        cat "${huellas[@]}"
    else
        echo "No existen huellas digitales"
    fi
}

# Funcion para consultar el almacenamiento
consultar_almacenamiento() {

    echo -e "${CELESTE}ESPACIO DE ALMACENAMIENTO${NORMAL}"

    echo "Espacio ocupado por los respaldos:"
    du -sh "$DESTINO"

    echo ""
    echo "Espacio disponible en el disco:"
    df -h "$DESTINO"
}

# Evitar errores cuando no existen archivos
shopt -s nullglob

# Modo automatico para tareas programadas
if [ "${1:-}" = "--automatico" ]; then
    crear_respaldo "$ORIGEN"
    exit $?
fi

# Menu interactivo principal
while true; do

    clear

    echo -e "${CELESTE}"
    echo "=========================================="
    echo "             RESPALDO SEGURO"
    echo "     Sistema de proteccion de archivos"
    echo "=========================================="
    echo -e "${NORMAL}"

    echo "Desarrollado por: Aaron"
    echo "Carrera: Ciberseguridad - V ciclo"
    echo "Version: 2.0"
    echo ""

    echo -e "${CELESTE}GESTION DE COPIAS DE SEGURIDAD${NORMAL}"
    echo "[1] Crear respaldo empresarial"
    echo "[2] Respaldar carpeta personalizada"
    echo "[3] Consultar contenido de un respaldo"

    echo ""

    echo -e "${CELESTE}CONTROL Y SEGURIDAD${NORMAL}"
    echo "[4] Consultar historial de operaciones"
    echo "[5] Revisar permisos y huellas digitales"
    echo "[6] Consultar espacio de almacenamiento"

    echo ""
    echo "[0] Salir del sistema"
    echo "=========================================="

    read -r -p "Seleccione una opcion: " opcion || exit 0

    echo ""

    case "$opcion" in

        1)
            crear_respaldo "$ORIGEN"
            ;;

        2)
            read -r -p "Ingrese la ruta de la carpeta: " ruta || exit 0
            crear_respaldo "$ruta"
            ;;

        3)
            consultar_respaldo
            ;;

        4)
            consultar_historial
            ;;

        5)
            consultar_seguridad
            ;;

        6)
            consultar_almacenamiento
            ;;

        0)
            echo -e "${VERDE}Gracias por utilizar Respaldo Seguro${NORMAL}"
            echo "Sesion finalizada correctamente"
            exit 0
            ;;

        *)
            echo -e "${ROJO}ERROR: Opcion no valida${NORMAL}"
            ;;

    esac

    echo ""
    echo -e "${AMARILLO}Presione Enter para continuar${NORMAL}"
    read -r || exit 0

done
