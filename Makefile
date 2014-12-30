gramar-files = dlog Dictionary/phones.list\
	Dictionary/phones.dict\
	Dictionary/Src/*.wordnet\
	Labels/train.phones.mlf

all: clean grammar build train

clean:
	rm -f $(gramar-files)
	rm -rf Mappings/*
	rm -rf Models/hmm*
	rm -rf Data/Lab

grammar:
	HDMan -m -w Dictionary/Src/word.list -n Dictionary/phones.list \
		-l dlog Dictionary/phones.dict Dictionary/Src/dict
	Scripts/add_silence_phones.sh
	HParse Dictionary/Src/grammar Dictionary/Src/grammar.wordnet
	HLEd -d Dictionary/phones.dict -i Labels/train.phones.mlf Configs/HLEd.config Labels/train.nosp.mlf

build:
	Scripts/hcopy_mapping.sh test
	mkdir Data/Lab
	mkdir Data/Lab/test
	HCopy -T 1 -C Configs/HCopy.config -S Mappings/HCopy.mapping
	mkdir Models/hmm0
	Scripts/hcompv_mapping.sh test
	HCompV -C Configs/HCompV.config -f 0.01 -m -S Mappings/HCompV.mapping -M Models/hmm0 Models/prototype
	Scripts/hmmdefs.sh
	Scripts/macro.sh

train:
	mkdir Models/hmm1
	HERest -T 0 -C Configs/HCompV.config -I Labels/train.phones.mlf -t 250.0 150.0 10000.0 -S Mappings/HCompV.mapping -H Models/hmm0/macros -H Models/hmm0/hmmdefs -M Models/hmm1 Dictionary/phones.list
