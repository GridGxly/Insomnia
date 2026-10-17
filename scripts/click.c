// click X Y: one left click at screen point X,Y. "move X Y" only moves the
// pointer; "right X Y" is one right click.
#include <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
  int move_only = argc == 4 && strcmp(argv[1], "move") == 0;
  int right = argc == 4 && strcmp(argv[1], "right") == 0;
  if (argc != 3 && !move_only && !right) return 2;
  CGPoint p = CGPointMake(atof(argv[argc - 2]), atof(argv[argc - 1]));
  CGWarpMouseCursorPosition(p);
  CGAssociateMouseAndMouseCursorPosition(true);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft));
  if (move_only) return 0;
  usleep(150000);
  CGEventType down = right ? kCGEventRightMouseDown : kCGEventLeftMouseDown;
  CGEventType up = right ? kCGEventRightMouseUp : kCGEventLeftMouseUp;
  CGMouseButton b = right ? kCGMouseButtonRight : kCGMouseButtonLeft;
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, down, p, b));
  usleep(80000);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, up, p, b));
  return 0;
}
