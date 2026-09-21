/*
  Flame NTS:

  Request window close atoms (os_linux.c)
  Fix dereferencing and equality checks on the xcb_state.mouseMode
  Uncomment all the other events once main key inputs work
  Test and test hard

  Test points:
   * Resize
   * Window termination
   * Fullscreen and stop fullscreen
   * Cursor customisation
*/

#include <linux/input.h>
#include <poll.h>
#include <xcb/xcb.h>
#include <xcb/xkb.h>
#include <xcb/xinput.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbcommon-x11.h>
#include <xkbcommon/xkbcommon-compose.h>

static struct {
  fn_quit* onQuit;
  fn_visible* onVisible;
  fn_focus* onFocus;
  fn_resize* onResize;
  fn_key* onKey;
  fn_text* onText;
  fn_mouse_button* onMouseButton;
  fn_mouse_move* onMouseMove;
  fn_mousewheel_move* onWheelMove;
}* event_callbacks;

static struct {
  // borrowed
  xcb_cursor_t hiddenCursor;
  xcb_connection_t* conn;
  xcb_window_t window;
  xcb_screen_t* screen;

  os_mouse_mode mouseMode; // read only pointer, our mouse mode function should return 0/1 to make clear if mouseMode was successfully set. Host then sets it
  uint8_t xkbCode;

  struct {
    uint32_t x;
    uint32_t y;
  }* windowSize;

  bool keyDown[OS_KEY_COUNT];

  // owned
  int16_t mouseX;
  int16_t mouseY;
  int16_t grabX;
  int16_t grabY;
} xcb_state;

static os_key xcb_convertKey(uint8_t keycode) {
  switch (keycode - 8) {
    case KEY_ESC: return OS_KEY_ESCAPE;
    case KEY_1: return OS_KEY_1;
    case KEY_2: return OS_KEY_2;
    case KEY_3: return OS_KEY_3;
    case KEY_4: return OS_KEY_4;
    case KEY_5: return OS_KEY_5;
    case KEY_6: return OS_KEY_6;
    case KEY_7: return OS_KEY_7;
    case KEY_8: return OS_KEY_8;
    case KEY_9: return OS_KEY_9;
    case KEY_0: return OS_KEY_0;
    case KEY_MINUS: return OS_KEY_MINUS;
    case KEY_EQUAL: return OS_KEY_EQUALS;
    case KEY_BACKSPACE: return OS_KEY_BACKSPACE;
    case KEY_TAB: return OS_KEY_TAB;
    case KEY_Q: return OS_KEY_Q;
    case KEY_W: return OS_KEY_W;
    case KEY_E: return OS_KEY_E;
    case KEY_R: return OS_KEY_R;
    case KEY_T: return OS_KEY_T;
    case KEY_Y: return OS_KEY_Y;
    case KEY_U: return OS_KEY_U;
    case KEY_I: return OS_KEY_I;
    case KEY_O: return OS_KEY_O;
    case KEY_P: return OS_KEY_P;
    case KEY_LEFTBRACE: return OS_KEY_LEFT_BRACKET;
    case KEY_RIGHTBRACE: return OS_KEY_RIGHT_BRACKET;
    case KEY_ENTER: return OS_KEY_ENTER;
    case KEY_LEFTCTRL: return OS_KEY_LEFT_CONTROL;
    case KEY_A: return OS_KEY_A;
    case KEY_S: return OS_KEY_S;
    case KEY_D: return OS_KEY_D;
    case KEY_F: return OS_KEY_F;
    case KEY_G: return OS_KEY_G;
    case KEY_H: return OS_KEY_H;
    case KEY_J: return OS_KEY_J;
    case KEY_K: return OS_KEY_K;
    case KEY_L: return OS_KEY_L;
    case KEY_SEMICOLON: return OS_KEY_SEMICOLON;
    case KEY_APOSTROPHE: return OS_KEY_APOSTROPHE;
    case KEY_GRAVE: return OS_KEY_BACKTICK;
    case KEY_LEFTSHIFT: return OS_KEY_LEFT_SHIFT;
    case KEY_BACKSLASH: return OS_KEY_BACKSLASH;
    case KEY_Z: return OS_KEY_Z;
    case KEY_X: return OS_KEY_X;
    case KEY_C: return OS_KEY_C;
    case KEY_V: return OS_KEY_V;
    case KEY_B: return OS_KEY_B;
    case KEY_N: return OS_KEY_N;
    case KEY_M: return OS_KEY_M;
    case KEY_COMMA: return OS_KEY_COMMA;
    case KEY_DOT: return OS_KEY_PERIOD;
    case KEY_SLASH: return OS_KEY_SLASH;
    case KEY_RIGHTSHIFT: return OS_KEY_RIGHT_SHIFT;
    case KEY_LEFTALT: return OS_KEY_LEFT_ALT;
    case KEY_SPACE: return OS_KEY_SPACE;
    case KEY_CAPSLOCK: return OS_KEY_CAPS_LOCK;
    case KEY_F1: return OS_KEY_F1;
    case KEY_F2: return OS_KEY_F2;
    case KEY_F3: return OS_KEY_F3;
    case KEY_F4: return OS_KEY_F4;
    case KEY_F5: return OS_KEY_F5;
    case KEY_F6: return OS_KEY_F6;
    case KEY_F7: return OS_KEY_F7;
    case KEY_F8: return OS_KEY_F8;
    case KEY_F9: return OS_KEY_F9;
    case KEY_F10: return OS_KEY_F10;
    case KEY_NUMLOCK: return OS_KEY_NUM_LOCK;
    case KEY_SCROLLLOCK: return OS_KEY_SCROLL_LOCK;
    case KEY_F11: return OS_KEY_F11;
    case KEY_F12: return OS_KEY_F12;
    case KEY_RIGHTCTRL: return OS_KEY_RIGHT_CONTROL;
    case KEY_RIGHTALT: return OS_KEY_RIGHT_ALT;
    case KEY_HOME: return OS_KEY_HOME;
    case KEY_UP: return OS_KEY_UP;
    case KEY_PAGEUP: return OS_KEY_PAGE_UP;
    case KEY_LEFT: return OS_KEY_LEFT;
    case KEY_RIGHT: return OS_KEY_RIGHT;
    case KEY_END: return OS_KEY_END;
    case KEY_DOWN: return OS_KEY_DOWN;
    case KEY_PAGEDOWN: return OS_KEY_PAGE_DOWN;
    case KEY_INSERT: return OS_KEY_INSERT;
    case KEY_DELETE: return OS_KEY_DELETE;
    case KEY_LEFTMETA: return OS_KEY_LEFT_OS;
    case KEY_RIGHTMETA: return OS_KEY_RIGHT_OS;
    default: return OS_KEY_COUNT;
  }
}

xcb_screen_t* xcb_get_screen(){
  const xcb_setup_t* setup = xcb_get_setup(xcb_state.conn);
  xcb_screen_iterator_t iter = xcb_setup_roots_iterator(setup);
  return iter.data;
}

void xcb_helper_init(void* callbacks, uint32_t* windowSizeRO){
  event_callbacks = callbacks;

  printf("GOT CALLBACKS %p\n",callbacks);
  printf("COUNT: %i\n",OS_KEY_COUNT);

  xcb_state.conn = (void*)os_get_xcb_connection();
  xcb_state.window = os_get_xcb_window();
  xcb_state.screen = xcb_get_screen();
  
  xcb_state.mouseMode = MOUSE_MODE_NORMAL;
  xcb_state.windowSize = (void*)windowSizeRO;
}

void xcb_poll_events(double timeout) {
  if (!xcb_state.conn) return;

  union {
    xcb_generic_event_t* any;
    xcb_ge_generic_event_t* generic;
    xcb_client_message_event_t* message;
    xcb_configure_notify_event_t* configure;
    xcb_map_notify_event_t* map;
    xcb_focus_in_event_t* focus;
    xcb_key_press_event_t* key;
    xcb_button_press_event_t* mouse;
    xcb_motion_notify_event_t* motion;
    xcb_input_raw_motion_event_t* raw;
    xcb_xkb_state_notify_event_t* keystate;
  } event;

  event.any = xcb_poll_for_event(xcb_state.conn);

  if (timeout != 0. && !event.any) {
    if (timeout < 0. || isinf(timeout)) {
      event.any = xcb_wait_for_event(xcb_state.conn);
    } else {
      xcb_flush(xcb_state.conn);
      struct pollfd fd = { xcb_get_file_descriptor(xcb_state.conn), POLLIN };
      poll(&fd, 1, (int) (timeout * 1000.));
      event.any = xcb_poll_for_event(xcb_state.conn);
    }
  }

  while (event.any) {
    uint8_t type = event.any->response_type & 0x7f;

    switch (type) {
      /*
      case XCB_CLIENT_MESSAGE:
        if (event.message->data.data32[0] == state.deleteWindow->atom && event_callbacks->onQuit) {
          event_callbacks->onQuit();
        }
        break;

      case XCB_CONFIGURE_NOTIFY:
        if (event.configure->width != xcb_state.windowSize->x || event.configure->height != xcb_state.windowSize->y) {
          //state.width = event.configure->width;
          //state.height = event.configure->height;
          if (state.onResize) {
            state.onResize(state.width, state.height);
          }
        }
        break;

      */
      case XCB_KEY_PRESS:
      case XCB_KEY_RELEASE: {
        uint8_t keycode = event.key->detail;
        os_key key = xcb_convertKey(keycode);
        bool press = type == XCB_KEY_PRESS;

        if (key < OS_KEY_COUNT) {
          os_button_action action = press ? BUTTON_PRESSED : BUTTON_RELEASED;
          bool repeat = press && xcb_state.keyDown[key];
          xcb_state.keyDown[key] = press;
          if (event_callbacks->onKey) event_callbacks->onKey(action, key, keycode, repeat);
        }

        /*if (press && state.onText) {
          xkb_keysym_t keysym = xkb_state_key_get_one_sym(state.keystate, keycode);
          xkb_compose_state_feed(state.compose, keysym);
          enum xkb_compose_status status = xkb_compose_state_get_status(state.compose);
          if (status == XKB_COMPOSE_COMPOSED) {
            xkb_keysym_t composed = xkb_compose_state_get_one_sym(state.compose);
            uint32_t codepoint = xkb_keysym_to_utf32(composed);
            state.onText(codepoint);
            xkb_compose_state_reset(state.compose);
          } else if (status == XKB_COMPOSE_CANCELLED) {
            xkb_compose_state_reset(state.compose);
          } else {
            uint32_t codepoint = xkb_state_key_get_utf32(state.keystate, keycode);
            state.onText(codepoint);
          }
        }*/
        break;
      }

      case XCB_BUTTON_PRESS:
      case XCB_BUTTON_RELEASE:
        switch (event.mouse->detail) {
          case 1: if (event_callbacks->onMouseButton) event_callbacks->onMouseButton(0, type == XCB_BUTTON_PRESS); break;
          case 2: if (event_callbacks->onMouseButton) event_callbacks->onMouseButton(2, type == XCB_BUTTON_PRESS); break;
          case 3: if (event_callbacks->onMouseButton) event_callbacks->onMouseButton(1, type == XCB_BUTTON_PRESS); break;
          case 4: if (event_callbacks->onWheelMove) event_callbacks->onWheelMove(0., +1.); break;
          case 5: if (event_callbacks->onWheelMove) event_callbacks->onWheelMove(0., -1.); break;
          case 6: if (event_callbacks->onWheelMove) event_callbacks->onWheelMove(+1., 0.); break;
          case 7: if (event_callbacks->onWheelMove) event_callbacks->onWheelMove(-1., 0.); break;
          default: if (event_callbacks->onMouseButton) event_callbacks->onMouseButton(event.mouse->detail - 5, type == XCB_BUTTON_PRESS); break;
        }
        break;

      case XCB_MOTION_NOTIFY:
        if (xcb_state.mouseMode == MOUSE_MODE_GRABBED) break;
        if (xcb_state.mouseX == event.motion->event_x && xcb_state.mouseY == event.motion->event_y) break;

        xcb_state.mouseX = event.motion->event_x;
        xcb_state.mouseY = event.motion->event_y;

        if (event_callbacks->onMouseMove) {
          event_callbacks->onMouseMove(event.motion->event_x, event.motion->event_y);
        }
        break;

      case XCB_GE_GENERIC:
        if (event.generic->event_type == XCB_INPUT_RAW_MOTION && xcb_state.mouseMode == MOUSE_MODE_GRABBED) {
          uint32_t* mask = xcb_input_raw_button_press_valuator_mask(event.raw);

          if (event_callbacks->onMouseMove && (mask[0] & 0x3) == 0x3) {
            xcb_input_fp3232_t* values = xcb_input_raw_button_press_axisvalues(event.raw);
            xcb_state.mouseX += values[0].integral;
            xcb_state.mouseY += values[1].integral;
            event_callbacks->onMouseMove(xcb_state.mouseX, xcb_state.mouseY);
          }
        }
        break;
      /*

      case XCB_MAP_NOTIFY:
      case XCB_UNMAP_NOTIFY:
        state.visible = type == XCB_MAP_NOTIFY;
        if (state.onVisible) state.onVisible(state.visible);
        break;

      case XCB_FOCUS_IN:
      case XCB_FOCUS_OUT:
        if (event.focus->mode == XCB_NOTIFY_MODE_GRAB || event.focus->mode == XCB_NOTIFY_MODE_UNGRAB) break;
        state.focused = type == XCB_FOCUS_IN;
        if (state.onFocus) state.onFocus(state.focused);
        break;

      default:
        if (event.any->response_type == state.xkbCode && event.keystate->xkbType == XCB_XKB_STATE_NOTIFY) {
          xkb_state_update_mask(
            state.keystate,
            event.keystate->baseMods,
            event.keystate->latchedMods,
            event.keystate->lockedMods,
            event.keystate->baseGroup,
            event.keystate->latchedGroup,
            event.keystate->lockedGroup
          );
        }
        break;
        */
    }

    free(event.any);

    event.any = xcb_poll_for_event(xcb_state.conn);
  }
}

bool xcb_set_mouse_mode(os_mouse_mode mode){
  struct {
    xcb_input_event_mask_t info;
    xcb_input_xi_event_mask_t mask;
  } rawInput;

  uint32_t x, y;
  os_window_get_size(&x, &y);

  xcb_connection_t* conn = xcb_state.conn;
  xcb_screen_t* screen = xcb_state.screen;
  xcb_window_t window = xcb_state.window;

  rawInput.info.deviceid = XCB_INPUT_DEVICE_ALL_MASTER;
  rawInput.info.mask_len = 1;
  rawInput.mask = mode == MOUSE_MODE_GRABBED ? XCB_INPUT_XI_EVENT_MASK_RAW_MOTION : 0;
  xcb_input_xi_select_events(xcb_state.conn, xcb_state.screen->root, 1, &rawInput.info);
  xcb_flush(xcb_state.conn);

  if (mode == MOUSE_MODE_GRABBED) {
    if (!xcb_state.hiddenCursor){
      xcb_state.hiddenCursor = xcb_generate_id(conn);
      xcb_pixmap_t pixmap = xcb_generate_id(conn);

      xcb_create_pixmap(conn, 1, pixmap, window, 1, 1);
      xcb_create_cursor(conn, xcb_state.hiddenCursor, pixmap, pixmap, 0, 0, 0, 0, 0, 0, 0, 0);
      xcb_free_pixmap(conn, pixmap);
    }

    uint32_t events = XCB_EVENT_MASK_BUTTON_PRESS
                     | XCB_EVENT_MASK_BUTTON_RELEASE
                     | XCB_EVENT_MASK_POINTER_MOTION;

    xcb_warp_pointer(conn,
      XCB_NONE,
      window,
      0, 0, 0, 0,
      x,y
    );

    xcb_grab_pointer(conn, 0, window, events, 1, 1, window, xcb_state.hiddenCursor, XCB_CURRENT_TIME);

    xcb_flush(conn);

    xcb_state.mouseMode = MOUSE_MODE_GRABBED;
  }

  return true;
}

bool xcb_get_mouse_mode(){
  return xcb_state.mouseMode;
}
