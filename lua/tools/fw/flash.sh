#!/bin/bash

FW=nodemcu-master-24-modules-2018-09-20-09-16-58-float.bin
DEFPORT=/dev/ttyUSB0
BAUD=250000
ESPTOOL=esptool.py

PORT=${1:-$DEFPORT}

FILE=$(cd `dirname $0` && pwd)/$FW

if [ ! -f $FILE ]; then
    echo "Firmware file $FILE not found"
    exit
fi

$ESPTOOL --port $PORT --baud $BAUD write_flash -fm qio 0x00000 $FILE
