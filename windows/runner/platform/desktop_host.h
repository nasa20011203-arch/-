#pragma once
#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>
#include <optional>
#include "desktop_shell.h"

class DesktopHost {
 public:
  DesktopHost(HWND window, flutter::BinaryMessenger* messenger);
  ~DesktopHost();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
 private:
  void Emit(const char* method, flutter::EncodableValue value = flutter::EncodableValue());
  bool SetMode(bool enabled);
  void EmitBounds();
  void RestoreBounds(const flutter::EncodableMap& args);
  bool SetAutoStart(bool enabled);
  void RecoverDesktop();
  HWND window_;
  DesktopShell shell_;
  bool desktop_requested_ = false;
  bool initialized_ = false;
  bool destroying_ = false;
  UINT taskbar_created_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
