#!/bin/bash

for item in `cat Dictionary/phones.list`
do
  (tail -n +4  Models/hmm0/prototype | sed 's/prototype/'$item'/g') >> Models/hmm0/hmmdefs
done
