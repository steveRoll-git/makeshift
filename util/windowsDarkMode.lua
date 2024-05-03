if love.system.getOS() ~= "Windows" then
  return
end

local ffi = require "ffi"

ffi.cdef [[
typedef void* HWND;
typedef void* HDC;
typedef void* HINSTANCE;
typedef void* LPCVOID;
typedef void* HRGN;
typedef unsigned long DWORD;
typedef int BOOL;
typedef long LONG;
typedef LONG HRESULT;
typedef unsigned int UINT;
typedef unsigned char Uint8;
typedef int SDL_bool;
typedef struct SDL_Window SDL_Window;

typedef struct SDL_version
{
  Uint8 major;
  Uint8 minor;
  Uint8 patch;
} SDL_version;

typedef enum SDL_SYSWM_TYPE
{
  SDL_SYSWM_UNKNOWN,
  SDL_SYSWM_WINDOWS,
  SDL_SYSWM_X11,
  SDL_SYSWM_DIRECTFB,
  SDL_SYSWM_COCOA,
  SDL_SYSWM_UIKIT,
  SDL_SYSWM_WAYLAND,
  SDL_SYSWM_MIR,
  SDL_SYSWM_WINRT,
  SDL_SYSWM_ANDROID,
  SDL_SYSWM_VIVANTE,
  SDL_SYSWM_OS2,
  SDL_SYSWM_HAIKU,
  SDL_SYSWM_KMSDRM,
  SDL_SYSWM_RISCOS
} SDL_SYSWM_TYPE;

typedef struct
{
  SDL_version version;
  SDL_SYSWM_TYPE subsystem;
  union
  {
      struct
      {
          HWND window;
          HDC hdc;
          HINSTANCE hinstance;
      } win;

      Uint8 dummy[64];
  } info;
} SDL_SysWMinfo;

typedef struct {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECT;

void SDL_GetVersion(SDL_version * ver);
SDL_Window* SDL_GL_GetCurrentWindow(void);
SDL_bool SDL_GetWindowWMInfo(SDL_Window * window,
                             SDL_SysWMinfo * info);

HRESULT DwmSetWindowAttribute(
  HWND    hwnd,
  DWORD   dwAttribute,
  LPCVOID pvAttribute,
  DWORD   cbAttribute
);
]]

local sdl2 = ffi.load("SDL2")
local dwmapi = ffi.load("Dwmapi")

local wmInfo = ffi.new("SDL_SysWMinfo")
sdl2.SDL_GetVersion(wmInfo.version)
sdl2.SDL_GetWindowWMInfo(sdl2.SDL_GL_GetCurrentWindow(), wmInfo)

local hwnd = wmInfo.info.win.window

local useDarkMode = ffi.new("BOOL[1]", 1)
dwmapi.DwmSetWindowAttribute(hwnd, 20, useDarkMode, ffi.sizeof(useDarkMode))
