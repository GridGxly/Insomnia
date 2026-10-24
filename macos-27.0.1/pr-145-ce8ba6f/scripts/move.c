// move X Y: put the pointer at X,Y without clicking.
#include <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  if (argc != 3) return 2;
  CGPoint p = CGPointMake(atof(argv[1]), atof(argv[2]));
  CGWarpMouseCursorPosition(p);
  CGAssociateMouseAndMouseCursorPosition(true);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft));
  return 0;
}
