#!/system/bin/sh
MODDIR=${0%/*}

mount --bind "$MODDIRomc_path" "omc_path"
