// click X Y: one left click at screen point X,Y (or "move X Y" to only move).
#include <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
  int move_only = argc == 4 && strcmp(argv[1], "move") == 0;
  if (argc != 3 && !move_only) return 2;
  CGPoint p = CGPointMake(atof(argv[argc - 2]), atof(argv[argc - 1]));
  CGWarpMouseCursorPosition(p);
  CGAssociateMouseAndMouseCursorPosition(true);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft));
  if (move_only) return 0;
  usleep(150000);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, p, kCGMouseButtonLeft));
  usleep(80000);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, p, kCGMouseButtonLeft));
  return 0;
}
