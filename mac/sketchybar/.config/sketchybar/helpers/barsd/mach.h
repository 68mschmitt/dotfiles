// Mach plumbing shared by barsd (Swift, via -import-objc-header) and bar_notify.
//  - sb_send(): send a command to SketchyBar as a NUL-separated argv (the same
//    wire format the sketchybar CLI uses), so arguments need no quoting.
//  - barsd_send(): send KEY\0VALUE\0... to the barsd event server.
//  - barsd_server_begin(): register a bootstrap service and deliver incoming
//    SketchyBar mach_helper events (KEY\0VALUE\0... pairs) to a callback.
#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <bootstrap.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BARSD_SERVICE "git.felix.barsd"

struct bm_message {
  mach_msg_header_t header;
  mach_msg_size_t descriptor_count;
  mach_msg_ool_descriptor_t descriptor;
};
struct bm_buffer {
  struct bm_message message;
  mach_msg_trailer_t trailer;
};

static inline mach_port_t bm_lookup(const char* name) {
  mach_port_t bs, port;
  if (task_get_special_port(mach_task_self(), TASK_BOOTSTRAP_PORT, &bs) != KERN_SUCCESS) return 0;
  if (bootstrap_look_up(bs, (char*)name, &port) != KERN_SUCCESS) return 0;
  return port;
}

static inline bool bm_send(mach_port_t port, const char* data, uint32_t len, mach_msg_timeout_t timeout) {
  if (!port) return false;
  struct bm_message msg = {0};
  msg.header.msgh_remote_port = port;
  msg.header.msgh_bits = MACH_MSGH_BITS_SET(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND, 0,
                                            MACH_MSGH_BITS_COMPLEX);
  msg.header.msgh_size = sizeof(struct bm_message);
  msg.descriptor_count = 1;
  msg.descriptor.address = (void*)data;
  msg.descriptor.size = len;
  msg.descriptor.copy = MACH_MSG_VIRTUAL_COPY;
  msg.descriptor.deallocate = false;
  msg.descriptor.type = MACH_MSG_OOL_DESCRIPTOR;
  return mach_msg(&msg.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(struct bm_message), 0,
                  MACH_PORT_NULL, timeout, MACH_PORT_NULL) == KERN_SUCCESS;
}

// Join argv with NULs (+ final NUL) and send.
static inline bool bm_send_argv(mach_port_t* cache, const char* service, const char** argv, int argc,
                                mach_msg_timeout_t timeout) {
  size_t len = 1;
  for (int i = 0; i < argc; i++) len += strlen(argv[i]) + 1;
  char* buf = (char*)malloc(len);
  size_t c = 0;
  for (int i = 0; i < argc; i++) { size_t l = strlen(argv[i]) + 1; memcpy(buf + c, argv[i], l); c += l; }
  buf[c++] = '\0';
  if (!*cache) *cache = bm_lookup(service);
  bool ok = bm_send(*cache, buf, (uint32_t)c, timeout);
  if (!ok) { *cache = bm_lookup(service); ok = bm_send(*cache, buf, (uint32_t)c, timeout); }
  free(buf);
  return ok;
}

// barsd sends to SketchyBar from its own serial queue (never the receive loop),
// so it can afford to wait for a busy SketchyBar instead of dropping commands.
static mach_port_t g_sb_port = 0;
static inline bool sb_send(const char** argv, int argc) {
  char name[256];
  const char* bar = getenv("BAR_NAME");
  snprintf(name, sizeof(name), "git.felix.%s", bar ? bar : "sketchybar");
  return bm_send_argv(&g_sb_port, name, argv, argc, 2000);
}

static mach_port_t g_barsd_port = 0;
static inline bool barsd_send(const char** argv, int argc) {
  return bm_send_argv(&g_barsd_port, BARSD_SERVICE, argv, argc, 100);
}

// ---- server ----
typedef void (*bm_handler)(const char* data, uint32_t len);
static bm_handler g_bm_handler = NULL;

static inline void bm_callback(CFMachPortRef port, void* message, CFIndex size, void* info) {
  struct bm_buffer* buffer = (struct bm_buffer*)message;
  if (buffer->message.descriptor_count > 0 && buffer->message.descriptor.address && g_bm_handler)
    g_bm_handler((const char*)buffer->message.descriptor.address, buffer->message.descriptor.size);
  mach_msg_destroy(&buffer->message.header);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline bool barsd_server_begin(bm_handler handler) {
  mach_port_t task = mach_task_self(), port, bs;
  if (mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) return false;
  struct mach_port_limits limits = {.mpl_qlimit = MACH_PORT_QLIMIT_LARGE};
  mach_port_set_attributes(task, port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits,
                           MACH_PORT_LIMITS_INFO_COUNT);
  if (mach_port_insert_right(task, port, port, MACH_MSG_TYPE_MAKE_SEND) != KERN_SUCCESS) return false;
  if (task_get_special_port(task, TASK_BOOTSTRAP_PORT, &bs) != KERN_SUCCESS) return false;
  if (bootstrap_register(bs, BARSD_SERVICE, port) != KERN_SUCCESS) return false;
  g_bm_handler = handler;
  CFMachPortContext ctx = {0, NULL, NULL, NULL, NULL};
  CFMachPortRef cf = CFMachPortCreateWithPort(NULL, port, bm_callback, &ctx, NULL);
  CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(NULL, cf, 0);
  CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopDefaultMode);
  CFRelease(src);
  CFRelease(cf);
  return true;
}
#pragma clang diagnostic pop
