#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#include <string.h>

static struct {
  bool active;
  GLFWgamepadstate current;
  GLFWgamepadstate previous;
} controllerState[GLFW_JOYSTICK_LAST];

static fn_joystick_button* onJoystickButton = NULL;
static fn_joystick_connection* onJoystickConnection = NULL;

static void glfwJoystickEvent(int jid, int e){

    controllerState[jid].active = glfwJoystickIsGamepad(jid);

    if (onJoystickConnection){
        onJoystickConnection(jid, controllerState[jid].active );
    }
}

void os_controller_init(){
#ifndef LOVR_USE_GLFW
  glfwInitHint(GLFW_PLATFORM, GLFW_PLATFORM_NULL);
  glfwInit();
#endif

  glfwSetJoystickCallback(glfwJoystickEvent);

  for (int i = 0; i < GLFW_JOYSTICK_LAST; i++){
    controllerState[i].active = glfwJoystickIsGamepad(i);
  }
}

void os_controller_poll(){
  if (!onJoystickButton) return;
  for (int i = 0; i < GLFW_JOYSTICK_LAST; i++){
      GLFWgamepadstate* prev = &controllerState[i].previous;
      GLFWgamepadstate* cur = &controllerState[i].current;

      memcpy(prev, cur, sizeof(GLFWgamepadstate));

      glfwGetGamepadState(i,cur);

      // lets virtualise the events (GLFW doesnt give joystick events, but we can fake it!)

      for (int j = 0; j < GLFW_GAMEPAD_BUTTON_LAST; j++){
          if (cur->buttons[j] != prev->buttons[j]){
              // where j IS a GLFW enum but it maps onto our os_gp enums well
              onJoystickButton(i,j,cur->buttons[j] == GLFW_PRESS);
          }
      }
  }
}

void os_controller_set_callbacks(fn_joystick_button* button, fn_joystick_connection* eve){
  onJoystickButton = button;
  onJoystickConnection = eve;
}

const char* os_controller_get_name(int jid){
    return glfwGetGamepadName(jid);
}

bool os_controller_is_active(int jid){
    return controllerState[jid].active;
}

void os_controller_update_mappings(const char* mappings){
  glfwUpdateGamepadMappings(mappings) == GLFW_TRUE;
  for (int i = 0; i < GLFW_JOYSTICK_LAST; i++){
    bool lastState = controllerState[i].active;
    controllerState[i].active = glfwJoystickIsGamepad(i);

    if (!lastState && controllerState[i].active){
        glfwJoystickEvent(i,1);
    }
  }
}

bool os_controller_get_button_down(int jid, os_gp button){
    return controllerState[jid].current.buttons[button] == GLFW_PRESS;
}

bool os_controller_button_pressed(int jid, os_gp button){
    return controllerState[jid].current.buttons[button] == GLFW_PRESS && controllerState[jid].previous.buttons[button] == GLFW_RELEASE;
}

bool os_controller_button_released(int jid, os_gp button){
    return controllerState[jid].current.buttons[button] == GLFW_RELEASE && controllerState[jid].previous.buttons[button] == GLFW_PRESS;
}

int os_controller_get_axes(float* to, int jid, os_axis axis){
    if (axis >= OS_AXIS_LEFT_TRIGGER){
        to[0] = controllerState[jid].current.axes[axis];
        return 1;
    }
    else {
        to[0] = controllerState[jid].current.axes[axis];
        to[1] = controllerState[jid].current.axes[axis + 1];
        return 2;
    }
}
