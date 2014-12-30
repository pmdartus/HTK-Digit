#!/bin/bash

EXPORT_PATH="./Data/Lab/"$1"/*"
MAPPING_FILE="Mappings/HCompV.mapping"

if [[ $# -eq 0 ]]; then
  echo "A directory should be specified: dev | test | train"
  exit 1
fi

for filename in $EXPORT_PATH; do
  echo $filename >> $MAPPING_FILE
done
