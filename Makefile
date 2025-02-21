GO					?= go
CLIPS_VERSION		?= 6.31
CLIPS_SOURCE_URL	?= "https://downloads.sourceforge.net/project/clipsrules/CLIPS/6.31/clips_core_source_631.zip"
MAKEFILE_NAME		?= makefile
SHARED_INCLUDE_DIR	?= /usr/local/include
SHARED_LIBRARY_DIR	?= /usr/local/lib

# platform detection
PLATFORM = $(shell uname -s)

.PHONY: clips clipsgo test install-clips clean

all: clips_source clips clipsgo

clips_source:
	wget -O /tmp/clips.zip $(CLIPS_SOURCE_URL)
	mkdir -p clips_source
	unzip -jo /tmp/clips.zip -d clips_source
	ln -s clips_source clips

ifeq ($(PLATFORM),Darwin) # macOS
clips_source/libclips.so: clips_source
	$(MAKE) -f $(MAKEFILE_NAME) -C clips_source \
		CFLAGS="-std=c99 -O3 -fno-strict-aliasing -fPIC" \
		LDLIBS="-lm"
	ld clips_source/*.o -lm -dylib -arch x86_64 \
		-o clips_source/libclips.so
else
clips_source/libclips.so: clips_source
	$(MAKE) -f $(MAKEFILE_NAME) -C clips_source \
		CFLAGS="-std=c99 -O3 -fno-strict-aliasing -fPIC" \
		LDLIBS="-lm -lrt"
	ld -G clips_source/*.o -o clips_source/libclips.so
endif

clips_source/libclips.a:
	$(MAKE) -j8 -f $(MAKEFILE_NAME) -C clips_source

clips: clips_source/libclips.a

clipsgo: clips
	$(GO) build -o clipsgo ./cmd/clipsgo

test: clips
	GODEBUG=cgocheck=2 $(GO) test -coverprofile=cover.out ./pkg/...

coverage: test
	go tool cover -html cover.out

install-clips: clips
	install -d $(SHARED_INCLUDE_DIR)/clips/
	install -m 644 clips_source/*.h $(SHARED_INCLUDE_DIR)/clips/
	install -d $(SHARED_LIBRARY_DIR)/
	install -m 644 clips_source/libclips.so \
	 	$(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION)
	ln -s $(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION) \
	 	$(SHARED_LIBRARY_DIR)/libclips.so.6
	ln -s $(SHARED_LIBRARY_DIR)/libclips.so.$(CLIPS_VERSION) \
	 	$(SHARED_LIBRARY_DIR)/libclips.so
	-ldconfig -n -v $(SHARED_LIBRARY_DIR)

clean:
	-rm /tmp/clips.zip
	-rm -fr clips_source clips build dist clipspy.egg-info
