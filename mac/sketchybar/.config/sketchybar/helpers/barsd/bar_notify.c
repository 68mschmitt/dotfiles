// bar_notify <SENDER> [KEY=VALUE ...]: send an event to barsd without a shell.
// Used by Rift subscriptions (bar_notify rift) and by plugin scripts.
// Extra arguments without '=' (e.g. the JSON Rift appends) are ignored.
#include "mach.h"

int main(int argc, char** argv) {
  if (argc < 2) { fprintf(stderr, "usage: bar_notify <sender> [KEY=VALUE...]\n"); return 1; }
  const char* out[2 * argc + 2];
  int n = 0;
  out[n++] = "SENDER"; out[n++] = argv[1];
  out[n++] = "NAME"; out[n++] = "barsd";
  char* copies[argc];
  int nc = 0;
  for (int i = 2; i < argc; i++) {
    char* eq = strchr(argv[i], '=');
    if (!eq || argv[i][0] == '{' || argv[i][0] == '[') continue;
    char* c = strdup(argv[i]); copies[nc++] = c;
    c[eq - argv[i]] = '\0';
    out[n++] = c; out[n++] = c + (eq - argv[i]) + 1;
  }
  bool ok = barsd_send(out, n);
  for (int i = 0; i < nc; i++) free(copies[i]);
  return ok ? 0 : 2;
}
