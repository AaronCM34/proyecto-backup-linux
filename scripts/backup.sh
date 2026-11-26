#!/bin/bash

# Proyecto: Sistema de copias de seguridad
# Autor: Aaron
# Curso: Shell Scripting
# Carrera: Ciberseguridad - V ciclo
# Version: 0.1
# Descripcion: Automatiza las copias de seguridad
# de archivos importantes en Linux.


#!/bin/bash

# Proyecto: Sistema de copias de seguridad
# Autor: Aaron
# Carrera: Ciberseguridad - V ciclo
# Version: 1.0
# Descripcion: Automatizar copias de seguridad en Linux.

# Permisos de seguridad
umask 077

# Declaracion de variables
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ORIGEN="$BASE/datos"
DESTINO="$BASE/backups"
LOG="$BASE/logs/backup.log"
FECHA=$(date +%Y-%m-%d_%H-%M-%S)
ARCHIVO="backup_${FECHA}_$$.tar.gz"

# Crear directorios necesarios
mkdir -p "$DESTINO" "$BASE/logs" || exit 1

# Validar existencia del directorio
if [ ! -d "$ORIGEN" ]; then
    echo "ERROR: El directorio no existe" | tee -a "$LOG"
    exit 1
fi

# Validar que el directorio no este vacio
if [ -z "$(ls -A "$ORIGEN")" ]; then
    echo "ERROR: El directorio esta vacio" | tee -a "$LOG"
    exit 1
fi

# Realizar copia de seguridad
if tar -czf "$DESTINO/$ARCHIVO" -C "$BASE" datos; then

    # Generar hash de integridad
    if sha256sum "$DESTINO/$ARCHIVO" > "$DESTINO/$ARCHIVO.sha256"; then
        echo "$FECHA - Backup realizado correctamente" | tee -a "$LOG"
        echo "Archivo generado: $ARCHIVO"
    else
        rm -f "$DESTINO/$ARCHIVO" "$DESTINO/$ARCHIVO.sha256"
        echo "ERROR: No se pudo generar el hash" | tee -a "$LOG"
        exit 1
    fi

else
    rm -f "$DESTINO/$ARCHIVO"
    echo "$FECHA - Error al realizar el backup" | tee -a "$LOG"
    exit 1
fi

exit 0
