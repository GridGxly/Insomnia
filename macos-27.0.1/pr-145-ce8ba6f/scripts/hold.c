// hold X Y MS: press the left button at X,Y, keep it down MS milliseconds,
// release. Nothing is sent in between, as with a still finger.
#include <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv) {
  if (argc != 4) return 2;
  CGPoint p = CGPointMake(atof(argv[1]), atof(argv[2]));
  CGWarpMouseCursorPosition(p);
  CGAssociateMouseAndMouseCursorPosition(true);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, p, kCGMouseButtonLeft));
  usleep(150000);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, p, kCGMouseButtonLeft));
  usleep(atoi(argv[3]) * 1000);
  CGEventPost(kCGHIDEventTap, CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, p, kCGMouseButtonLeft));
  return 0;
}
