CC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa

nowplaying-cli: nowplaying.mm
	$(CC) $(CFLAGS) $(FRAMEWORKS) $< -o $@

clean:
	rm -f nowplaying-cli