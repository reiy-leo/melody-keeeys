#include "include/native_core/native_core_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "native_core_plugin.h"

void NativeCorePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  native_core::NativeCorePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
