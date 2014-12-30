gramar-files = dlog Dictionary/phones.list Dictionary/phones.dict Dictionary/Src/*.wordnet

all: build

clean:
	rm -f $(gramar-files)

build:
	HDMan -m -w Dictionary/Src/word.list -n Dictionary/phones.list \
		-l dlog Dictionary/phones.dict Dictionary/Src/dict
	Scripts/add_silence_phones.sh
	HParse Dictionary/Src/grammar Dictionary/Src/grammar.wordnet
