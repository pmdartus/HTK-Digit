#!/bin/bash

DEFAULT_LOG=/dev/null
LOG_FILE=${1:-$DEFAULT_LOG}

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
  rm -f $LOG_FILE
}

log_cmd() {
  read IN
  $IN >> $LOG_FILE
  echo "" >> $LOG_FILE
  echo "" >> $LOG_FILE
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
  HDMan -A -T 1 -m -w Dictionary/Src/word.list -n Dictionary/phones-with-sp.list -g ./Configs/global.ded -l dlog $PHONES_DICT Dictionary/Src/dict | log_cmd
  echo "sil" >> Dictionary/phones-with-sp.list
  sed '/sp/d' Dictionary/phones-with-sp.list > $PHONE_LIST
  echo "sil   sil" >> $PHONES_DICT

  # Sort the updated dict
  TMP_DICT="Dictionary/tmp"
  sort $PHONES_DICT >> $TMP_DICT
  rm $PHONES_DICT
  mv $TMP_DICT $PHONES_DICT

  # Create word net
  HParse -A -T 1 Dictionary/Src/grammar Dictionary/Src/grammar.wordnet | log_cmd

  # Convert to phones
  HLEd -A -d $PHONES_DICT -i Labels/train.phones.mlf -l './Data/Lab/train' Configs/HLEd.config Labels/train.nosp.mlf | log_cmd
  HLEd -A -d $PHONES_DICT -i Labels/train.phones-with-sp.mlf -l './Data/Lab/train' Configs/HLEd-with-sp.config Labels/train.nosp.mlf | log_cmd

  echo "    >> Features extraction"
  generate_hcopy_mapping train
  HCopy -A -D -C Configs/HCopy.config -S Mappings/HCopy_train.mapping | log_cmd

  echo "    >> Test preparation"
  generate_hcopy_mapping dev
  HCopy -A -D -C Configs/HCopy.config -S Mappings/HCopy_dev.mapping | log_cmd
  create_mapping HVite "./Data/Lab/dev/*"
}

#================================
#           TRAINNING
#================================

estimate() {
  ITERATION=$1
  NEXT=$(($ITERATION + 1))

  MLF=$2
  LIST=$3
  CMD=$4

  echo "    >> Estimate $NEXT"
  mkdir Models/hmm$NEXT
  HERest -A -D -C Configs/HERest.config -I Labels/$MLF -t 250.0 150.0 30000.0 $4 -S Mappings/HERest.mapping\
       -H Models/hmm$ITERATION/macros -H Models/hmm$ITERATION/hmmdefs -M Models/hmm$NEXT Dictionary/$LIST | log_cmd
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
  HHEd -A -H Models/hmm$NEXT/macros -H Models/hmm$NEXT/hmmdefs -M Models/hmm$NEXT_NEXT Configs/HHEd.config Dictionary/phones-with-sp.list | log_cmd
}

align() {
  IT=$1

  echo "    >> Aligning MLF"
  create_mapping HVite_align "./Data/Lab/train/*"
  HVite -A -D -l './Data/Lab/train' -b sil -o SWT -C Configs/HVite.config -H Models/hmm$IT/macros -H Models/hmm$IT/hmmdefs\
      -i Labels/aligned.mlf -m -t 250.0 150.0 1000.0 -y lab -a -I Labels/train.nosp.mlf -S Mappings/HVite_align.mapping $PHONES_DICT Dictionary/phones-with-sp.list | log_cmd
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

triphone() {
  echo "    >> Triphones"
  HLEd -A -D -n Dictionary/triphones.list -l "./Data/Lab/train" -i Labels/triphones.mlf Configs/HLEd-triphone.config Labels/aligned.mlf | log_cmd
  perl ./HTK_scripts/maketrihed Dictionary/phones-with-sp.list Dictionary/triphones.list

  mkdir Models/hmm10
  HHEd -A -H Models/hmm9/macros -H Models/hmm9/hmmdefs -M Models/hmm10 mktri.hed Dictionary/phones-with-sp.list | log_cmd
}

make_tied_state() {
  echo "    >> Make tied state"
  grep -v "[bdglmpy]\|ao\|aa\|ae\|aw\|ax\|ch\|en\|er\|hh\|jh\|sh\|uh\|zh" Dictionary/Src/dict > Dictionary/Src/dict_fixed
  HDMan -A -D -b sp -n Dictionary/fulllist.list -g Config/global.ded -l flog Dictionary/tri.dict Dictionary/Src/dict_fixed | log_cmd

  cp Dictionary/fulllist.list Dictionary/fulllist1.list
  cat Dictionary/triphones.list >> Dictionary/fulllist1.list
  perl HTK_Scripts/fixfulllist Dictionary/fulllist1.list Dictionary/fulllist.list

  rm Dictionary/fulllist1.list

  rm Configs/tree.hed
  cp Configs/tree.template Configs/tree.hed
  perl HTK_Scripts/mkcls TB 350 Dictionary/phones.list >> Configs/tree.hed

  echo "" >> Configs/tree.hed
  echo "TR 1" >> Configs/tree.hed
  echo "" >> Configs/tree.hed
  echo "AU \"Dictionary/fulllist.list\"" >> Configs/tree.hed
  echo "CO \"Dictionary/tiedlist.list\"" >> Configs/tree.hed
  echo "" >> Configs/tree.hed
  echo "ST \"trees\"" >> Configs/tree.hed

  mkdir Models/hmm13
  HHEd -A -H Models/hmm12/macros -H Models/hmm12/hmmdefs -M Models/hmm13 Configs/tree.hed Dictionary/triphones.list | log_cmd
}

train() {
  echo "TRAINNING"
  echo "    >> Init"
  mkdir Models/hmm0
  create_mapping HCompV "./Data/Lab/train/*"
  HCompV -A -D -C Configs/HCompV.config -f 0.01 -m -S Mappings/HCompV.mapping -M Models/hmm0 Models/prototype | log_cmd

  generate_hmmdefs
  generate_macros
  create_mapping HERest "./Data/Lab/train/*"

  for i in {0..2}
  do
    estimate $i train.phones.mlf phones.list
  done
  fix_silence_model 3
  for i in {5..6}
  do
    estimate $i train.phones-with-sp.mlf phones-with-sp.list
  done
  align 7
  for i in {7..8}
  do
    estimate $i aligned.mlf phones-with-sp.list
  done

  triphone
  estimate 10 triphones.mlf triphones.list
  estimate 11 triphones.mlf triphones.list "-s stats"

  make_tied_state
  estimate 13 triphones.mlf tiedlist.list "-s stats"
  estimate 14 triphones.mlf tiedlist.list "-s stats"
}


#================================
#               TEST
#================================

testing() {
  ITERATION=$1
  echo "TESTING"
  echo "    >> With model $ITERATION"

  HVite -A -D -H Models/hmm$ITERATION/macros -H Models/hmm$ITERATION/hmmdefs -S Mappings/HVite.mapping -i Labels/aligned_$ITERATION.mlf \
      -w Dictionary/Src/grammar.wordnet -p 0.0 -s 5.0 $PHONES_DICT Dictionary/tiedlist.list | log_cmd
}

#================================
#             EVALUATE
#================================

evaluate() {
  HResults -I Labels/dev.ref.mlf Dictionary/tiedlist.list Labels/aligned_15.mlf
}


main() {
  clean
  data_prep
  train
  testing 15
  evaluate 15
}

main

