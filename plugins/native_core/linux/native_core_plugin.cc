#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <glib.h>

#include <atomic>
#include <cstring>
#include <ctime>
#include <thread>
#include <vector>

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define NATIVE_CORE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), native_core_plugin_get_type(), NativeCorePlugin))

struct _NativeCorePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(NativeCorePlugin, native_core_plugin, g_object_get_type())

namespace {

FlMethodChannel* g_method_channel = nullptr;
FlEventChannel* g_event_channel = nullptr;

std::atomic<bool> g_hook_running{false};
std::thread g_hook_thread;

// Emitted to the event channel; must run on the GTK main thread.
struct KeyEventData {
  int64_t code;
  bool down;
  bool repeat;
  int64_t ts_ms;
};

gboolean EmitKeyEventOnMain(gpointer user_data) {
  auto* event = static_cast<KeyEventData*>(user_data);
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "code", fl_value_new_int(event->code));
  fl_value_set_string_take(map, "down", fl_value_new_bool(event->down));
  fl_value_set_string_take(map, "repeat", fl_value_new_bool(event->repeat));
  fl_value_set_string_take(map, "ts", fl_value_new_int(event->ts_ms));
  fl_event_channel_send(g_event_channel, map, nullptr, nullptr);
  fl_value_unref(map);
  delete event;
  return G_SOURCE_REMOVE;  // one-shot
}

int64_t NowEpochMs() {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}

// True when the device looks like a keyboard: it can produce key events for
// the main typing block (letters/space) rather than just media/power keys.
bool IsKeyboard(int fd) {
  uint8_t key_bits[KEY_MAX / 8 + 1] = {};
  if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(key_bits)), key_bits) < 0) return false;
  auto has = [](const uint8_t* bits, int code) {
    return bits[code / 8] & (1 << (code % 8));
  };
  return has(key_bits, KEY_A) && has(key_bits, KEY_SPACE) && has(key_bits, KEY_ENTER);
}

void HookThreadProc() {
  std::vector<int> fds;
  for (int attempt = 0; attempt < 3 && fds.empty(); attempt++) {
    if (DIR* dir = opendir("/dev/input")) {
      while (dirent* entry = readdir(dir)) {
        if (strncmp(entry->d_name, "event", 5) != 0) continue;
        std::string path = std::string("/dev/input/") + entry->d_name;
        int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC);
        if (fd < 0) continue;  // not in `input` group -> EACCES
        if (IsKeyboard(fd)) {
          fds.push_back(fd);
        } else {
          close(fd);
        }
      }
      closedir(dir);
    }
    if (fds.empty()) sleep(2);  // devices may appear late (USB/Bluetooth)
  }
  if (fds.empty()) {
    g_hook_running.store(false);
    return;
  }

  std::vector<pollfd> pfds;
  for (int fd : fds) pfds.push_back({fd, POLLIN, 0});

  while (g_hook_running.load()) {
    int rc = poll(pfds.data(), pfds.size(), 250);
    if (rc <= 0) continue;
    for (auto& pfd : pfds) {
      if (!(pfd.revents & POLLIN)) continue;
      input_event events[16];
      ssize_t n = read(pfd.fd, events, sizeof(events));
      if (n < 0) continue;
      int count = static_cast<int>(n / sizeof(input_event));
      for (int i = 0; i < count; i++) {
        const input_event& e = events[i];
        if (e.type != EV_KEY) continue;
        auto* data = new KeyEventData{
            .code = e.code,
            .down = e.value == 1,
            .repeat = e.value == 2,
            .ts_ms = NowEpochMs(),
        };
        // Hop to the GTK main loop for the (non-thread-safe) event channel.
        g_idle_add_full(G_PRIORITY_DEFAULT, EmitKeyEventOnMain, data, nullptr);
      }
    }
  }
  for (int fd : fds) close(fd);
}

FlMethodResponse* HandleMethodCall(const gchar* method) {
  if (strcmp(method, "isPermissionGranted") == 0) {
    // evdev read access requires membership in the `input` group.
    bool granted = false;
    if (DIR* dir = opendir("/dev/input")) {
      granted = true;
      bool any_opened = false;
      while (dirent* entry = readdir(dir)) {
        if (strncmp(entry->d_name, "event", 5) != 0) continue;
        std::string path = std::string("/dev/input/") + entry->d_name;
        int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC);
        if (fd >= 0) {
          any_opened = true;
          close(fd);
        }
      }
      closedir(dir);
      granted = any_opened;
    }
    FlValue* result = fl_value_new_bool(granted);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  if (strcmp(method, "openPermissionSettings") == 0) {
    // No GUI toggle exists for group membership; the app shows instructions.
    FlValue* result = fl_value_new_bool(false);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  if (strcmp(method, "startKeyHook") == 0) {
    if (!g_hook_running.load()) {
      g_hook_running.store(true);
      g_hook_thread = std::thread(HookThreadProc);
    }
    FlValue* result = fl_value_new_bool(g_hook_running.load());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  if (strcmp(method, "stopKeyHook") == 0) {
    if (g_hook_running.exchange(false) && g_hook_thread.joinable()) {
      g_hook_thread.detach();  // thread exits on its next poll timeout
    }
    FlValue* result = fl_value_new_bool(true);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

void native_core_plugin_handle_method_call(NativeCorePlugin* self,
                                           FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response =
      HandleMethodCall(fl_method_call_get_name(method_call));
  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  NativeCorePlugin* plugin = NATIVE_CORE_PLUGIN(user_data);
  native_core_plugin_handle_method_call(plugin, method_call);
}

static void native_core_plugin_dispose(GObject* object) {
  if (g_hook_running.exchange(false) && g_hook_thread.joinable()) {
    g_hook_thread.detach();
  }
  G_OBJECT_CLASS(native_core_plugin_parent_class)->dispose(object);
}

static void native_core_plugin_class_init(NativeCorePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = native_core_plugin_dispose;
}

static void native_core_plugin_init(NativeCorePlugin* self) {}

}  // namespace

void native_core_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  NativeCorePlugin* plugin = NATIVE_CORE_PLUGIN(
      g_object_new(native_core_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  g_method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "native_core/method",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "native_core/keyhook",
      FL_METHOD_CODEC(codec));

  g_object_unref(plugin);
}
