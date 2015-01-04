#!/bin/bash

PHONES_DICT="Dictionary/phones.dict"
PHONE_LIST="Dictionary/phones.list"
RECORDED_PATH="./Data/Recorded/"
EXPORT_PATH="./Data/Lab/"

GRAMMAR_FILES="dlog\
  Dictionary/phones*\
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

generate_hcopy_mapping() {
  MODE=$1
  mkdir $EXPORT_PATH$MODE
  DIR_PATH=$RECORDED_PATH$MODE"/*"
  MAPPING_FILE="./Mappings/HCopy_$MODE.mapping"
  for filename in $DIR_PATH; do
    BASE_NAME=$(basename $filename)
    BASE_WITHOUT_EXT="${BASE_NAME%.*}"
    echo $filename' '$EXPORT_PATH$MODE"/"$BASE_WITHOUT_EXT'.lab' >> $MAPPING_FILE
  done
}

data_prep() {
  echo "DATA PREP"
  echo "    >> Grammar generation"
  HDMan -m -w Dictionary/Src/word.list -n Dictionary/phones-with-sp.list -g ./Configs/global.ded -l dlog $PHONES_DICT Dictionary/Src/dict
  sed '/sp/d' Dictionary/phones-with-sp.list > $PHONE_LIST
  echo "sil   sil" >> $PHONES_DICT

  # Sort the updated dict
  TMP_DICT="Dictionary/tmp"
  sort $PHONES_DICT >> $TMP_DICT
  rm $PHONES_DICT
  mv $TMP_DICT $PHONES_DICT

  # Create word net
  HParse Dictionary/Src/grammar Dictionary/Src/grammar.wordnet

  # Convert to phones
  HLEd -d $PHONES_DICT -i Labels/train.phones.mlf -l './Data/Lab/train' Configs/HLEd.config Labels/train.nosp.mlf
  HLEd -d $PHONES_DICT -i Labels/train.phones-with-sp.mlf -l './Data/Lab/train' Configs/HLEd-with-sp.config Labels/train.nosp.mlf

  echo "    >> Features extraction"
  generate_hcopy_mapping train
  HCopy -T 1 -C Configs/HCopy.config -S Mappings/HCopy_train.mapping > /dev/null

  echo "    >> Test preparation"
  generate_hcopy_mapping dev
  HCopy -T 1 -C Configs/HCopy.config -S Mappings/HCopy_dev.mapping > /dev/null
  create_mapping HVite "./Data/Lab/dev/*"
}

#================================
#           TRAINNING
#================================

estimate() {
  ITERATION=$1
  NEXT=$(($ITERATION + 1))

  echo "    >> Estimate $NEXT"
  mkdir Models/hmm$NEXT
  HERest -T 1 -C Configs/HERest.config -I Labels/train.phones.mlf -t 250.0 150.0 10000.0 -S Mappings/HERest.mapping\
       -H Models/hmm$ITERATION/macros -H Models/hmm$ITERATION/hmmdefs -M Models/hmm$NEXT Dictionary/phones.list >> /dev/null
}

fix_silence_model() {
  ITERATION=$1
  NEXT=$(($ITERATION + 1))
  NEXT_NEXT=$(($ITERATION + 2))

  echo "    >> Update model with sp $NEXT"
  mkdir Models/hmm$NEXT
  cp -r Models/hmm$ITERATION/* Models/hmm$NEXT

  echo "~h \"sp\"" >> Models/hmm$NEXT/hmmdefs
  echo "<BEGINHMM>" >> Models/hmm$NEXT/hmmdefs
  echo "<NUMSTATES> 3" >> Models/hmm$NEXT/hmmdefs
  echo "<STATE> 2" >> Models/hmm$NEXT/hmmdefs

  sed -n '518,522p' < Models/hmm$NEXT/hmmdefs >> Models/hmm$NEXT/hmmdefs

  echo "<TRANSP> 3" >> Models/hmm$NEXT/hmmdefs
  echo " 0.0 1.0 0.0" >> Models/hmm$NEXT/hmmdefs
  echo " 0.0 0.9 0.1" >> Models/hmm$NEXT/hmmdefs
  echo " 0.0 0.0 0.0" >> Models/hmm$NEXT/hmmdefs
  echo "<ENDHMM>" >> Models/hmm$NEXT/hmmdefs

  echo "    >> Fix silence model $NEXT_NEXT"
  mkdir Models/hmm$NEXT_NEXT
  HHEd -H Models/hmm$NEXT/macros -H Models/hmm$NEXT/hmmdefs -M Models/hmm$NEXT_NEXT Configs/HHEd.config Dictionary/phones-with-sp.list
}

generate_hmmdefs() {
  for item in `cat $PHONE_LIST`
  do
    (tail -n +4  Models/hmm0/prototype | sed 's/prototype/'$item'/g') >> Models/hmm0/hmmdefs
  done
}

generate_macros() {
  echo "~o" > Models/hmm0/macros
  echo "<STREAMINFO> 1 39" >> Models/hmm0/macros
  echo "<VECSIZE> 39<NULLD><MFCC_E_D_A><DIAGC>" >> Models/hmm0/macros
  cat Models/hmm0/vFloors >> Models/hmm0/macros
}

train() {
  echo "TRAINNING"
  echo "    >> Init"
  mkdir Models/hmm0
  create_mapping HCompV "./Data/Lab/train/*"
  HCompV -C Configs/HCompV.config -f 0.01 -m -S Mappings/HCompV.mapping -M Models/hmm0 Models/prototype

  generate_hmmdefs
  generate_macros
  create_mapping HERest "./Data/Lab/train/*"

  for i in {0..2}
  do
    estimate $i
  done
  fix_silence_model 3
}

#================================
#               TEST
#================================

testing() {
  ITERATION=$1
  echo "TESTING"
  echo "    >> With model $ITERATION"

  HVite -H Models/hmm$ITERATION/macros -H Models/hmm$ITERATION/hmmdefs -S Mappings/HVite.mapping -i Labels/aligned_$ITERATION.mlf \
      -w Dictionary/Src/grammar.wordnet -p 0.0 -s 5.0 $PHONES_DICT Dictionary/phones-with-sp.list
}

#================================
#             EVALUATE
#================================

evaluate() {
  HResults -I Labels/dev.ref.mlf Dictionary/Src/word.list Labels/aligned_$1.mlf
}


main() {
  clean
  data_prep
  train
}

main
