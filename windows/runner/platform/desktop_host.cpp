#include "desktop_host.h"
#include <flutter/standard_method_codec.h>
#include <shellscalingapi.h>
#include <algorithm>
#include <string>
#include <vector>

namespace {
constexpr UINT_PTR kRecoveryTimer = 0xCA11;
double Number(const flutter::EncodableMap& args, const char* name, double fallback) {
  auto found = args.find(flutter::EncodableValue(name));
  if (found == args.end()) return fallback;
  if (const auto* value = std::get_if<double>(&found->second)) return *value;
  if (const auto* value = std::get_if<int32_t>(&found->second)) return *value;
  return fallback;
}
bool Boolean(const flutter::EncodableMap& args, const char* name) {
  auto found = args.find(flutter::EncodableValue(name));
  return found != args.end() && std::get_if<bool>(&found->second) &&
      std::get<bool>(found->second);
}
}

DesktopHost::DesktopHost(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window), taskbar_created_(::RegisterWindowMessageW(L"TaskbarCreated")) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
    messenger, "offline_calendar/desktop", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto& method = call.method_name();
    if (method == "initialize") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (!args) { result->Error("arguments", "Expected settings map"); return; }
      RestoreBounds(*args);
      const bool attached = SetMode(Boolean(*args, "desktopMode"));
      initialized_ = true;
      ::SetTimer(window_, kRecoveryTimer, 2000, nullptr);
      result->Success(flutter::EncodableValue(attached));
    } else if (method == "setDesktopMode") {
      const auto* value = std::get_if<bool>(call.arguments());
      if (!value) { result->Error("arguments", "Expected boolean"); return; }
      const bool attached = SetMode(*value);
      if (!*value && desktop_requested_) {
        result->Error("desktop", "Could not detach desktop window"); return;
      }
      result->Success(flutter::EncodableValue(attached));
    } else if (method == "setAutoStart") {
      const auto* value = std::get_if<bool>(call.arguments());
      if (!value || !SetAutoStart(*value)) result->Error("registry", "Could not update startup registration");
      else result->Success();
    } else if (method == "beginDrag" || method == "beginResize") {
      ::ReleaseCapture();
      ::SendMessageW(window_, WM_NCLBUTTONDOWN,
        method == "beginDrag" ? HTCAPTION : HTBOTTOMRIGHT, 0);
      EmitBounds();
      result->Success();
    } else if (method == "destroy") {
      destroying_ = true;
      result->Success();
      ::PostMessageW(window_, WM_CLOSE, 0, 0);
    } else result->NotImplemented();
  });
}
DesktopHost::~DesktopHost() {
  ::KillTimer(window_, kRecoveryTimer);
  channel_->SetMethodCallHandler(nullptr);
}
void DesktopHost::Emit(const char* method, flutter::EncodableValue value) {
  channel_->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(std::move(value)));
}
bool DesktopHost::SetMode(bool enabled) {
  if (!enabled) {
    if (!shell_.Detach(window_)) return false;
    desktop_requested_ = false;
    ::SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    return false;
  }
  desktop_requested_ = shell_.Attach(window_);
  if (!desktop_requested_) shell_.Detach(window_);
  return desktop_requested_;
}
void DesktopHost::RestoreBounds(const flutter::EncodableMap& args) {
  // x/y are physical virtual-screen coordinates; width/height are logical DIPs.
  LONG x = static_cast<LONG>(Number(args, "x", 100));
  LONG y = static_cast<LONG>(Number(args, "y", 100));
  RECT proposed{x, y, x + 200, y + 200};
  HMONITOR monitor = ::MonitorFromRect(&proposed, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!::GetMonitorInfoW(monitor, &info)) return;
  UINT dpi_x = 96, dpi_y = 96;
  ::GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y);
  const double scale = dpi_x / 96.0;
  const int available_width = info.rcWork.right - info.rcWork.left;
  const int available_height = info.rcWork.bottom - info.rcWork.top;
  const int width = std::min(available_width,
      static_cast<int>(std::max(560.0, Number(args, "width", 980)) * scale));
  const int height = std::min(available_height,
      static_cast<int>(std::max(420.0, Number(args, "height", 720)) * scale));
  x = std::clamp(x, info.rcWork.left, info.rcWork.right - width);
  y = std::clamp(y, info.rcWork.top, info.rcWork.bottom - height);
  ::SetWindowPos(window_, HWND_NOTOPMOST, x, y, width, height,
      SWP_NOACTIVATE | SWP_FRAMECHANGED);
}
void DesktopHost::EmitBounds() {
  if (!initialized_ || ::IsIconic(window_) || !::IsWindow(window_)) return;
  RECT rect{};
  if (!::GetWindowRect(window_, &rect)) return;
  const double scale = ::GetDpiForWindow(window_) / 96.0;
  if (scale <= 0) return;
  Emit("boundsChanged", flutter::EncodableMap{
    {flutter::EncodableValue("x"), flutter::EncodableValue(static_cast<double>(rect.left))},
    {flutter::EncodableValue("y"), flutter::EncodableValue(static_cast<double>(rect.top))},
    {flutter::EncodableValue("width"), flutter::EncodableValue((rect.right - rect.left) / scale)},
    {flutter::EncodableValue("height"), flutter::EncodableValue((rect.bottom - rect.top) / scale)}});
}
bool DesktopHost::SetAutoStart(bool enabled) {
  HKEY key = nullptr;
  const auto opened = ::RegCreateKeyExW(HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, nullptr,
      0, KEY_SET_VALUE, nullptr, &key, nullptr);
  if (opened != ERROR_SUCCESS) return false;
  LSTATUS status;
  if (enabled) {
    std::vector<wchar_t> path(32768);
    DWORD size = ::GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (!size || size >= path.size()) { ::RegCloseKey(key); return false; }
    const std::wstring command = L"\"" + std::wstring(path.data(), size) + L"\"";
    status = ::RegSetValueExW(key, L"OfflineCalendar", 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    status = ::RegDeleteValueW(key, L"OfflineCalendar");
    if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
  }
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}
void DesktopHost::RecoverDesktop() {
  if (!desktop_requested_ || destroying_) return;
  if (shell_.Healthy(window_)) return;
  if (!shell_.Detach(window_) || !shell_.Attach(window_)) {
    shell_.Detach(window_);
    desktop_requested_ = false;
    ::ShowWindow(window_, SW_SHOWNORMAL);
    Emit("desktopFallback");
  }
}
std::optional<LRESULT> DesktopHost::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_CLOSE && initialized_ && !destroying_) {
    Emit("closeRequested");
    return 0;
  }
  if (message == WM_TIMER && wparam == kRecoveryTimer) {
    RecoverDesktop();
    return 0;
  }
  if (taskbar_created_ && message == taskbar_created_) {
    RecoverDesktop();
  }
  if (message == WM_EXITSIZEMOVE) EmitBounds();
  if (message == WM_DPICHANGED) {
    // The standard Flutter runner applies the suggested rect; persist afterward.
    ::PostMessageW(window_, WM_APP + 1, 0, 0);
  }
  if (message == WM_APP + 1) EmitBounds();
  return std::nullopt;
}
