gramar-files = dlog Dictionary/phones.list\
	Dictionary/phones.dict\
	Dictionary/Src/*.wordnet\
	Labels/train.phones.mlf

all: clean grammar build

clean:
	rm -f $(gramar-files)
	rm -rf Mappings/*

grammar:
	HDMan -m -w Dictionary/Src/word.list -n Dictionary/phones.list \
		-l dlog Dictionary/phones.dict Dictionary/Src/dict
	Scripts/add_silence_phones.sh
	HParse Dictionary/Src/grammar Dictionary/Src/grammar.wordnet
	HLEd -d Dictionary/phones.dict -i Labels/train.phones.mlf Configs/HLEd.config Labels/train.nosp.mlf

build:
	Scripts/hcopy_mapping.sh test
