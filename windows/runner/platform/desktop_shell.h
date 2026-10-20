#pragma once
#include <windows.h>

// The only module relying on undocumented Explorer messages/WorkerW hierarchy.
// Acceptance by Win32 is NOT proof of Win+D, DPI or Explorer compatibility.
class DesktopShell {
 public:
  bool Attach(HWND window);
  bool Detach(HWND window);
  bool Healthy(HWND window) const;
 private:
  HWND worker_ = nullptr;
  LONG_PTR style_ = 0;
  LONG_PTR ex_style_ = 0;
};
