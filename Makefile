CC = clang++
OBJC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa
INCLUDES = -I./include

MINI_DIR = src/mediaremote-mini
MINI_BUILD_DIR = build/mediaremote-mini
MINI_DYLIB = $(MINI_BUILD_DIR)/MediaRemoteMini.dylib
MINI_INCLUDES = -I$(MINI_DIR)/include -I$(MINI_DIR)
MINI_FRAMEWORKS = -framework Foundation -framework AppKit -framework JavaScriptCore -framework UniformTypeIdentifiers
MINI_SRC = \
	$(MINI_DIR)/adapter/env.m \
	$(MINI_DIR)/adapter/get.m \
	$(MINI_DIR)/adapter/globals.m \
	$(MINI_DIR)/adapter/keys.m \
	$(MINI_DIR)/adapter/now_playing.m \
	$(MINI_DIR)/private/MediaRemote.m \
	$(MINI_DIR)/utility/helpers.m

all: $(MINI_DYLIB) nowplaying-cli

$(MINI_DYLIB): $(MINI_SRC) scripts/mediaremote-mini.pl
	mkdir -p $(MINI_BUILD_DIR)
	$(OBJC) -dynamiclib -fobjc-arc -fvisibility=default $(MINI_INCLUDES) $(MINI_FRAMEWORKS) \
		-o $(MINI_DYLIB) $(MINI_SRC)
	codesign --force --sign - $(MINI_DYLIB) >/dev/null || true
	chmod +x scripts/mediaremote-mini.pl

nowplaying-cli: src/nowplaying.mm $(MINI_DYLIB)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(INCLUDES) $< -o $@

clean:
	rm -f nowplaying-cli
	rm -rf $(MINI_BUILD_DIR)
