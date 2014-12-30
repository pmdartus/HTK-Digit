#!/bin/bash

RECORDED_PATH="./Data/Recorded/"$1"/*"
EXPORT_PATH="./Data/Lab/"$1"/"
MAPPING_FILE="Mappings/HCopy.mapping"

if [[ $# -eq 0 ]]; then
  echo "A directory should be specified: dev | test | train"
  exit 1
fi

for filename in $RECORDED_PATH; do
  NAME=$(echo $filename | sed 's/.*'$1'\/\(.*\)\.08/\1/')
  echo $filename' '$EXPORT_PATH$NAME'.lab' >> $MAPPING_FILE
done
