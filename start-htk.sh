#!/bin/bash

PHONES_DICT="Dictionary/phones.dict"
PHONE_LIST="Dictionary/phones.list"
RECORDED_PATH="./Data/Recorded/"
EXPORT_PATH="./Data/Lab/"

GRAMMAR_FILES="dlog\
  Dictionary/phones.list\
  Dictionary/phones.dict\
  Dictionary/Src/*.wordnet\
  Labels/train.phones.mlf"

#================================
#             UTILS
#================================

create_mapping() {
  NAME=$1
  FOLDER=$2

  MAPPING_FILE="./Mappings/"$1".mapping"
  for filename in $FOLDER; do
    echo $filename >> $MAPPING_FILE
  done
}

clean() {
  echo "CLEAN"
  rm -f $GRAMMAR_FILES
  rm -rf Mappings/*
  rm -rf Models/hmm*
  rm -rf Data/Lab/*
}

#================================
#         DATA PREP
#================================

add_silence() {
  # Add silence in the word dict
  echo "sent-end  []  sil" >> $PHONES_DICT
  echo "sent-start  []  sil" >> $PHONES_DICT
  echo "sil  []  sil" >> $PHONES_DICT

  # Sort the updated dict
  TMP_DICT="Dictionary/tmp"
  sort $PHONES_DICT >> $TMP_DICT
  rm $PHONES_DICT
  mv $TMP_DICT $PHONES_DICT

  #Add silence in the list
  echo "sil" >> $PHONE_LIST
}

generate_hcopy_mapping() {
  MODE=$1
  DIR_PATH=$RECORDED_PATH$MODE"/*"
  MAPPING_FILE="./Mappings/HCopy.mapping"
  for filename in $DIR_PATH; do
    BASE_NAME=$(basename $filename)
    BASE_WITHOUT_EXT="${BASE_NAME%.*}"
    echo $filename' '$EXPORT_PATH$MODE"/"$BASE_WITHOUT_EXT'.lab' >> $MAPPING_FILE
  done
}

data_prep() {
  echo "DATA PREP"
  echo "    >> Grammar generation"
  HDMan -m -w Dictionary/Src/word.list -n $PHONE_LIST -l dlog $PHONES_DICT Dictionary/Src/dict
  add_silence

  # Create word net
  HParse Dictionary/Src/grammar Dictionary/Src/grammar.wordnet

  # Convert to phones
  HLEd -d $PHONES_DICT -i Labels/train.phones.mlf Configs/HLEd.config Labels/train.nosp.mlf

  echo "    >> Features extraction"
  mkdir ./Data/Lab/train
  generate_hcopy_mapping train
  HCopy -T 1 -C Configs/HCopy.config -S Mappings/HCopy.mapping > /dev/null
}

#================================
#           TRAINNING
#================================

train() {
  echo "TRAINNING"
  echo "    >> Init"
  mkdir Models/hmm0
  create_mapping HCompV "./Data/Lab/train/*"
  HCompV -C Configs/HCompV.config -f 0.01 -m -S Mappings/HCompV.mapping -M Models/hmm0 Models/prototype
}

main() {
  clean
  data_prep
  train
}

main
