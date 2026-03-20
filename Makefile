CC = clang++
OBJC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa
INCLUDES = -I./include
ADAPTER_BUILD_DIR = build/mediaremote-adapter
ADAPTER_FRAMEWORK = $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework
ADAPTER_SCRIPT = vendor/mediaremote-adapter/bin/mediaremote-adapter.pl
ADAPTER_SRC_DIR = vendor/mediaremote-adapter
ADAPTER_SRC = \
	$(ADAPTER_SRC_DIR)/src/adapter/env.m \
	$(ADAPTER_SRC_DIR)/src/adapter/get.m \
	$(ADAPTER_SRC_DIR)/src/adapter/globals.m \
	$(ADAPTER_SRC_DIR)/src/adapter/keys.m \
	$(ADAPTER_SRC_DIR)/src/adapter/now_playing.m \
	$(ADAPTER_SRC_DIR)/src/adapter/repeat.m \
	$(ADAPTER_SRC_DIR)/src/adapter/seek.m \
	$(ADAPTER_SRC_DIR)/src/adapter/send.m \
	$(ADAPTER_SRC_DIR)/src/adapter/shuffle.m \
	$(ADAPTER_SRC_DIR)/src/adapter/speed.m \
	$(ADAPTER_SRC_DIR)/src/adapter/stream.m \
	$(ADAPTER_SRC_DIR)/src/adapter/test.m \
	$(ADAPTER_SRC_DIR)/src/private/MediaRemote.m \
	$(ADAPTER_SRC_DIR)/src/utility/Debounce.m \
	$(ADAPTER_SRC_DIR)/src/utility/helpers.m
ADAPTER_INCLUDES = -I$(ADAPTER_SRC_DIR)/include -I$(ADAPTER_SRC_DIR)/src
ADAPTER_FRAMEWORK_FLAGS = -framework Foundation -framework AppKit -framework JavaScriptCore -framework UniformTypeIdentifiers

all: nowplaying-cli

$(ADAPTER_FRAMEWORK): $(ADAPTER_SRC) $(ADAPTER_SCRIPT)
	mkdir -p $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework/Versions/A
	$(OBJC) -dynamiclib -fobjc-arc -fvisibility=default $(ADAPTER_INCLUDES) $(ADAPTER_FRAMEWORK_FLAGS) \
		-install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
		-o $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
		$(ADAPTER_SRC)
	ln -sfn A $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework/Versions/Current
	ln -sfn Versions/Current/MediaRemoteAdapter $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework/MediaRemoteAdapter
	codesign --force --sign - $(ADAPTER_BUILD_DIR)/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter >/dev/null || true

nowplaying-cli: src/nowplaying.mm $(ADAPTER_FRAMEWORK) $(ADAPTER_SCRIPT)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(INCLUDES) $< -o $@

clean:
	rm -f nowplaying-cli
	rm -rf build/mediaremote-adapter
