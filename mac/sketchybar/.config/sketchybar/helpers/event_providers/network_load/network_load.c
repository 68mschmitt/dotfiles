#include <unistd.h>
#include "network.h"
#include "../sketchybar.h"

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 4 || (sscanf(argv[3], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<interface>\" \"<event-name>\" \"<event_freq>\" [item]\n", argv[0]);
    exit(1);
  }
  // local addition: with [item], set "↓ 12K ↑ 3K" and push a log-scaled download
  // value to <item>.graph directly (no script per tick)
  const char* item = argc > 4 ? argv[4] : NULL;

  alarm(0);
  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[2]);
  sketchybar(event_message);

  struct network network;
  network_init(&network, argv[1]);
  char trigger_message[512];
  for (;;) {
    // Acquire new info
    network_update(&network);

    if (item) {
      static const char* u[] = { "B", "K", "M" };
      double down_bytes = network.down * pow(1000, network.down_unit);
      double g = log10(1 + down_bytes) / 8.0; if (g > 1) g = 1; if (g < 0) g = 0;
      snprintf(trigger_message, 512, "--set %s label=\"↓%4d%s ↑%4d%s\" --push %s.graph %.3f",
               item, network.down, u[network.down_unit], network.up, u[network.up_unit], item, g);
      sketchybar(trigger_message);
      usleep(update_freq * 1000000);
      continue;
    }
    // Prepare the event message
    snprintf(trigger_message,
             512,
             "--trigger '%s' upload='%03d%s' download='%03d%s'",
             argv[2],
             network.up,
             unit_str[network.up_unit],
             network.down,
             unit_str[network.down_unit]);

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
