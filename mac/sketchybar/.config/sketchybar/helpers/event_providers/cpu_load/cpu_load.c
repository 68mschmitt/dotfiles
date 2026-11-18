#include "cpu.h"
#include "../sketchybar.h"

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\" [item]\n", argv[0]);
    exit(1);
  }
  // local addition: with [item], set <item>'s label/colour and push <item>.graph
  // directly instead of triggering an event (no script per tick)
  const char* item = argc > 3 ? argv[3] : NULL;

  alarm(0);
  struct cpu cpu;
  cpu_init(&cpu);

  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    // Acquire new info
    cpu_update(&cpu);

    if (item) {
      if (cpu.total_load < 0 || cpu.total_load > 100) { usleep(update_freq * 1000000); continue; }
      const char* color = cpu.total_load >= 80 ? "0xffed8796" : cpu.total_load >= 50 ? "0xffeed49f" : "0xffcad3f5";
      snprintf(trigger_message, 512, "--set %s label=%d%% label.color=%s --push %s.graph %.2f",
               item, cpu.total_load, color, item, cpu.total_load / 100.0);
      sketchybar(trigger_message);
      usleep(update_freq * 1000000);
      continue;
    }
    // Prepare the event message
    snprintf(trigger_message,
             512,
             "--trigger '%s' user_load='%d' sys_load='%02d' total_load='%02d'",
             argv[1],
             cpu.user_load,
             cpu.sys_load,
             cpu.total_load                                        );

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
