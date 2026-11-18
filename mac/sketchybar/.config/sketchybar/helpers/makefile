# Builds the SketchyBar helper binaries into bin/ (git-ignored).
#   make -C ~/.config/sketchybar/helpers
BIN := bin
EP  := event_providers
PROVIDERS := $(BIN)/cpu_load $(BIN)/network_load $(BIN)/memory_load

all: $(PROVIDERS) $(BIN)/dock_badges

$(BIN):
	mkdir -p $(BIN)

$(BIN)/cpu_load: $(EP)/cpu_load/cpu_load.c $(EP)/cpu_load/cpu.h $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/network_load: $(EP)/network_load/network_load.c $(EP)/network_load/network.h $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/memory_load: $(EP)/memory_load/memory_load.c $(EP)/sketchybar.h | $(BIN)
	clang -std=c99 -O3 $< -o $@

$(BIN)/dock_badges: dock_badges.swift | $(BIN)
	swiftc -O $< -o $@

clean:
	rm -rf $(BIN)

.PHONY: all clean
