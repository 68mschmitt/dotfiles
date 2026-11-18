// memory_load "<event-name>" "<event_freq>"
// Triggers <event-name> with used_percent / used_gb / total_gb, where "used"
// matches Activity Monitor: app memory (internal - purgeable) + wired + compressed.
#include <mach/mach.h>
#include <stdbool.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include "../sketchybar.h"

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

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
    vm_statistics64_data_t vm;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (total && host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) == KERN_SUCCESS) {
      uint64_t app = vm.internal_page_count > vm.purgeable_count
                     ? (uint64_t)(vm.internal_page_count - vm.purgeable_count) : 0;
      uint64_t used = (app + vm.wire_count + vm.compressor_page_count) * (uint64_t)page;
      snprintf(trigger_message, 512,
               "--trigger '%s' used_percent='%d' used_gb='%.1f' total_gb='%.0f'",
               argv[1], (int)(100.0 * used / total + 0.5),
               used / 1073741824.0, total / 1073741824.0);
      sketchybar(trigger_message);
    }
    usleep(update_freq * 1000000);
  }
  return 0;
}
