#!/bin/bash

PHONES_DICT="Dictionary/phones.dict"
PHONE_LIST="Dictionary/phones.list"
TMP_DICT="Dictionary/tmp.dict"

# Add silence in the word dict
echo "SENT-END      []   sil" >> $PHONES_DICT
echo "SENT-START    [] sil" >> $PHONES_DICT
echo "SIL           []  sil" >> $PHONES_DICT

# Sort the updated dict
sort $PHONES_DICT >> $TMP_DICT
rm $PHONES_DICT
mv $TMP_DICT $PHONES_DICT

#Add silence in the list
echo "sil" >> $PHONE_LIST
