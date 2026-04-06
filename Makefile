CXX = clang++
OBJC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa
INCLUDES = -I./include
PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin
LIB_DIR = $(PREFIX)/lib/nowplaying-cli
SHARE_DIR = $(PREFIX)/share/nowplaying-cli

MINI_DIR = src/mediaremote-mini
MINI_BUILD_DIR = build/mediaremote-mini
MINI_DYLIB = $(MINI_BUILD_DIR)/MediaRemoteMini.dylib
MINI_INCLUDES = -I$(MINI_DIR)/include -I$(MINI_DIR)
MINI_FRAMEWORKS = -framework Foundation -framework AppKit -framework UniformTypeIdentifiers
MINI_HEADERS = $(wildcard $(MINI_DIR)/**/*.h) $(wildcard $(MINI_DIR)/*.h)
MINI_SRC = \
	$(MINI_DIR)/adapter/env.m \
	$(MINI_DIR)/adapter/get.m \
	$(MINI_DIR)/adapter/globals.m \
	$(MINI_DIR)/adapter/keys.m \
	$(MINI_DIR)/adapter/now_playing.m \
	$(MINI_DIR)/private/MediaRemote.m \
	$(MINI_DIR)/utility/helpers.m

all: $(MINI_DYLIB) nowplaying-cli

$(MINI_DYLIB): $(MINI_SRC) $(MINI_HEADERS)
	mkdir -p $(MINI_BUILD_DIR)
	$(OBJC) -dynamiclib -fobjc-arc -fvisibility=default $(CFLAGS) $(MINI_INCLUDES) $(MINI_FRAMEWORKS) \
		-o $(MINI_DYLIB) $(MINI_SRC)
	codesign --force --sign - $(MINI_DYLIB) >/dev/null 2>&1 || true

nowplaying-cli: src/nowplaying.mm $(MINI_DYLIB)
	$(CXX) $(CFLAGS) $(FRAMEWORKS) $(INCLUDES) $< -o $@

install: all
	mkdir -p $(DESTDIR)$(BIN_DIR) $(DESTDIR)$(LIB_DIR) $(DESTDIR)$(SHARE_DIR)/scripts
	cp nowplaying-cli $(DESTDIR)$(BIN_DIR)/nowplaying-cli
	cp $(MINI_DYLIB) $(DESTDIR)$(LIB_DIR)/MediaRemoteMini.dylib
	cp scripts/mediaremote-mini.pl $(DESTDIR)$(SHARE_DIR)/scripts/mediaremote-mini.pl
	chmod 755 $(DESTDIR)$(BIN_DIR)/nowplaying-cli $(DESTDIR)$(SHARE_DIR)/scripts/mediaremote-mini.pl

uninstall:
	rm -f $(DESTDIR)$(BIN_DIR)/nowplaying-cli
	rm -f $(DESTDIR)$(LIB_DIR)/MediaRemoteMini.dylib
	rm -f $(DESTDIR)$(SHARE_DIR)/scripts/mediaremote-mini.pl

clean:
	rm -f nowplaying-cli
	rm -rf $(MINI_BUILD_DIR)
