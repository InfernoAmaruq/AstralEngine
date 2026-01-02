#include <stdbool.h>
#include <stdint.h>

#pragma once

struct os_window_config;

typedef enum {
  PERMISSION_AUDIO_CAPTURE
} Permission;

bool lovrSystemInit(void);
void lovrSystemDestroy(void);
const char* lovrSystemGetOS(void);
uint32_t lovrSystemGetCoreCount(void);
void lovrSystemOpenConsole(void);
void lovrSystemRequestPermission(Permission permission);
bool lovrSystemOpenWindow(struct os_window_config* config);
bool lovrSystemIsWindowOpen(void);
bool lovrSystemIsWindowVisible(void);
bool lovrSystemIsWindowFocused(void);
void lovrSystemGetWindowSize(uint32_t* width, uint32_t* height);
void lovrSystemSetWindowFullscreen(bool fs);
bool lovrSystemIsWindowFullscreen(void);
float lovrSystemGetWindowDensity(void);
void lovrSystemPollEvents(void);
bool lovrSystemIsKeyDown(int keycode);
bool lovrSystemWasKeyPressed(int keycode);
bool lovrSystemWasKeyReleased(int keycode);
bool lovrSystemHasKeyRepeat(void);
void lovrSystemSetKeyRepeat(bool repeat);
void lovrSystemGetMousePosition(double* x, double* y);
bool lovrSystemIsMouseDown(int button);
bool lovrSystemWasMousePressed(int button);
bool lovrSystemWasMouseReleased(int button);
void lovrSystemSetWindowSize(uint32_t w,uint32_t h);
bool lovrSystemIsMouseGrabbed(void);
void lovrSystemSetMouseGrabbed(bool grabbed);
float lovrSystemGetScrollDelta(void);
const char* lovrSystemGetClipboardText(void);
void lovrSystemSetClipboardText(const char* text);

void lovrSystemSetCursorInputMode(int);
uint32_t lovrSystemGetCursorInputMode();
