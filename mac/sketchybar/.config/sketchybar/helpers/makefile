# Builds the SketchyBar helper binaries into bin/ (git-ignored).
#   make -C ~/.config/sketchybar/helpers
BIN := bin
EP  := event_providers
PROVIDERS := $(BIN)/cpu_load $(BIN)/network_load $(BIN)/memory_load

all: $(PROVIDERS) $(BIN)/bar_display $(BIN)/barsd $(BIN)/bar_notify

$(BIN):
	mkdir -p $(BIN)

$(BIN)/cpu_load: $(EP)/cpu_load/cpu_load.c $(EP)/cpu_load/cpu.h $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/network_load: $(EP)/network_load/network_load.c $(EP)/network_load/network.h $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@ -lm

$(BIN)/memory_load: $(EP)/memory_load/memory_load.c $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/barsd: barsd/main.swift barsd/mach.h | $(BIN)
	swiftc -O -swift-version 5 -import-objc-header barsd/mach.h barsd/main.swift -o $@ \
	  -F /System/Library/PrivateFrameworks -framework SkyLight

$(BIN)/bar_notify: barsd/bar_notify.c barsd/mach.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/bar_display: bar_display.swift | $(BIN)
	swiftc -O $< -o $@ -F /System/Library/PrivateFrameworks -framework SkyLight

clean:
	rm -rf $(BIN)

.PHONY: all clean
