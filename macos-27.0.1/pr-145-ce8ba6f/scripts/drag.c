// drag X Y MS X2 Y2 MS2: press the left button at X,Y, keep it still MS
// milliseconds, drag to X2,Y2 in 6 steps over 60 ms, keep it down MS2
// milliseconds there, release at X2,Y2.
#include <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>
#include <unistd.h>
static void post(CGEventType t, CGPoint p) {
  CGEventRef e = CGEventCreateMouseEvent(NULL, t, p, kCGMouseButtonLeft);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}
int main(int argc, char **argv) {
  if (argc != 7) return 2;
  CGPoint a = CGPointMake(atof(argv[1]), atof(argv[2]));
  CGPoint b = CGPointMake(atof(argv[4]), atof(argv[5]));
  CGWarpMouseCursorPosition(a);
  CGAssociateMouseAndMouseCursorPosition(true);
  post(kCGEventMouseMoved, a);
  usleep(150000);
  post(kCGEventLeftMouseDown, a);
  usleep(atoi(argv[3]) * 1000);
  for (int i = 1; i <= 6; i++) {
    CGPoint p = CGPointMake(a.x + (b.x - a.x) * i / 6, a.y + (b.y - a.y) * i / 6);
    post(kCGEventLeftMouseDragged, p);
    usleep(10000);
  }
  usleep(atoi(argv[6]) * 1000);
  post(kCGEventLeftMouseUp, b);
  return 0;
}
