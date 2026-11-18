// memory_load "<event-name>" "<event_freq>" [item]   |   memory_load --print
// Triggers <event-name> with used_percent / used_gb / total_gb, where "used"
// matches Activity Monitor: app memory (internal - purgeable) + wired + compressed.
// With [item] it sets <item>'s label/colour and pushes <item>.graph directly;
// --print writes "percent used_gb total_gb" once (for the popup).
#include <mach/mach.h>
#include <stdbool.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include "../sketchybar.h"

static int sample(host_t host, vm_size_t page, uint64_t total, double* used_gb) {
  vm_statistics64_data_t vm;
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  if (!total || host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) != KERN_SUCCESS) return -1;
  uint64_t app = vm.internal_page_count > vm.purgeable_count
                 ? (uint64_t)(vm.internal_page_count - vm.purgeable_count) : 0;
  uint64_t used = (app + vm.wire_count + vm.compressor_page_count) * (uint64_t)page;
  *used_gb = used / 1073741824.0;
  return (int)(100.0 * used / total + 0.5);
}

int main(int argc, char** argv) {
  float update_freq;
  if (argc == 2 && strcmp(argv[1], "--print") == 0) {
    uint64_t total = 0; size_t len = sizeof(total);
    sysctlbyname("hw.memsize", &total, &len, NULL, 0);
    vm_size_t page = 0; host_page_size(mach_host_self(), &page);
    double gb = 0; int pct = sample(mach_host_self(), page, total, &gb);
    printf("%d %.1f %.0f\n", pct, gb, total / 1073741824.0);
    return pct < 0;
  }
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\" [item] | --print\n", argv[0]);
    exit(1);
  }
  const char* item = argc > 3 ? argv[3] : NULL;

  alarm(0);
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  uint64_t total = 0;
  size_t len = sizeof(total);
  sysctlbyname("hw.memsize", &total, &len, NULL, 0);
  host_t host = mach_host_self();
  vm_size_t page = 0;
  host_page_size(host, &page);

  char trigger_message[512];
  for (;;) {
    double gb = 0;
    int pct = sample(host, page, total, &gb);
    if (pct >= 0) {
      if (item) {
        const char* color = pct >= 85 ? "0xffed8796" : pct >= 70 ? "0xffeed49f" : "0xffcad3f5";
        snprintf(trigger_message, 512, "--set %s label=%d%% label.color=%s --push %s.graph %.2f",
                 item, pct, color, item, pct / 100.0);
      } else {
        snprintf(trigger_message, 512,
                 "--trigger '%s' used_percent='%d' used_gb='%.1f' total_gb='%.0f'",
                 argv[1], pct, gb, total / 1073741824.0);
      }
      sketchybar(trigger_message);
    }
    usleep(update_freq * 1000000);
  }
  return 0;
}
