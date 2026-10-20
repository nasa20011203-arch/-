#include "desktop_shell.h"

namespace {
BOOL CALLBACK FindWorker(HWND top, LPARAM context) {
  if (::FindWindowExW(top, nullptr, L"SHELLDLL_DefView", nullptr)) {
    auto* result = reinterpret_cast<HWND*>(context);
    *result = ::FindWindowExW(nullptr, top, L"WorkerW", nullptr);
  }
  return TRUE;
}
void RestoreScreenRect(HWND window, HWND parent, const RECT& screen) {
  POINT point{screen.left, screen.top};
  if (parent) ::MapWindowPoints(HWND_DESKTOP, parent, &point, 1);
  ::SetWindowPos(window, HWND_BOTTOM, point.x, point.y,
                 screen.right - screen.left, screen.bottom - screen.top,
                 SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
}
}

bool DesktopShell::Attach(HWND window) {
  if (Healthy(window)) return true;
  if (worker_) Detach(window);
  HWND progman = ::FindWindowW(L"Progman", nullptr);
  if (!progman) return false;
  DWORD_PTR ignored = 0;
  // Explorer-private request. Bounded to avoid freezing the application.
  if (!::SendMessageTimeoutW(progman, 0x052C, 0, 0, SMTO_ABORTIFHUNG,
                             1000, &ignored)) return false;
  HWND candidate = nullptr;
  ::EnumWindows(FindWorker, reinterpret_cast<LPARAM>(&candidate));
  if (!candidate || !::IsWindow(candidate)) return false;
  RECT rect{};
  if (!::GetWindowRect(window, &rect)) return false;
  style_ = ::GetWindowLongPtrW(window, GWL_STYLE);
  ex_style_ = ::GetWindowLongPtrW(window, GWL_EXSTYLE);
  ::SetWindowLongPtrW(window, GWL_STYLE,
    (style_ & ~static_cast<LONG_PTR>(WS_POPUP | WS_CAPTION)) | WS_CHILD);
  ::SetWindowLongPtrW(window, GWL_EXSTYLE,
    (ex_style_ & ~static_cast<LONG_PTR>(WS_EX_APPWINDOW | WS_EX_TOPMOST)) | WS_EX_TOOLWINDOW);
  ::SetLastError(0);
  ::SetParent(window, candidate);
  const DWORD error = ::GetLastError();
  if (error != ERROR_SUCCESS || ::GetParent(window) != candidate) {
    ::SetParent(window, nullptr);
    ::SetWindowLongPtrW(window, GWL_STYLE, style_);
    ::SetWindowLongPtrW(window, GWL_EXSTYLE, ex_style_);
    RestoreScreenRect(window, nullptr, rect);
    return false;
  }
  worker_ = candidate;
  RestoreScreenRect(window, worker_, rect);
  return true;
}

bool DesktopShell::Detach(HWND window) {
  if (!worker_) return true;
  RECT rect{};
  ::GetWindowRect(window, &rect);
  ::SetLastError(0);
  ::SetParent(window, nullptr);
  if (::GetLastError() != ERROR_SUCCESS || ::GetParent(window) != nullptr) return false;
  ::SetWindowLongPtrW(window, GWL_STYLE, style_);
  ::SetWindowLongPtrW(window, GWL_EXSTYLE,
      ex_style_ & ~static_cast<LONG_PTR>(WS_EX_TOPMOST));
  worker_ = nullptr;
  RestoreScreenRect(window, nullptr, rect);
  return true;
}

bool DesktopShell::Healthy(HWND window) const {
  return worker_ && ::IsWindow(worker_) && ::IsWindow(window) &&
         ::GetParent(window) == worker_;
}
