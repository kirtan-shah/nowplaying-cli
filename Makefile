CC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa
INCLUDES = -I./include

nowplaying-cli: src/nowplaying.mm
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(INCLUDES) $< -o $@

clean:
	rm -f nowplaying-cli