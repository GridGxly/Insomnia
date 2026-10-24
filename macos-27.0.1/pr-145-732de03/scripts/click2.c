// click2 X1 Y X2 GAPMS HOLDMS: click at X1,Y (80 ms press), then GAPMS after
// that release press at X2,Y, keep it down HOLDMS, release. Prints each
// event's time in ms after the first press.
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
static struct timespec t0;
static double ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (t.tv_sec - t0.tv_sec) * 1e3 + (t.tv_nsec - t0.tv_nsec) / 1e6;
}
static void post(CGEventType t, CGPoint p) {
  CGEventRef e = CGEventCreateMouseEvent(NULL, t, p, kCGMouseButtonLeft);
  CGEventPost(kCGHIDEventTap, e);
  CFRelease(e);
}
int main(int argc, char **argv) {
  if (argc != 6) return 2;
  CGPoint a = CGPointMake(atof(argv[1]), atof(argv[2]));
  CGPoint b = CGPointMake(atof(argv[3]), atof(argv[2]));
  int gap = atoi(argv[4]), hold = atoi(argv[5]);
  CGWarpMouseCursorPosition(a);
  CGAssociateMouseAndMouseCursorPosition(true);
  post(kCGEventMouseMoved, a);
  usleep(150000);
  clock_gettime(CLOCK_MONOTONIC, &t0);
  post(kCGEventLeftMouseDown, a);
  usleep(80000);
  post(kCGEventLeftMouseUp, a);
  double up1 = ms();
  usleep(gap * 500);
  post(kCGEventMouseMoved, b);
  usleep(gap * 500);
  post(kCGEventLeftMouseDown, b);
  double down2 = ms();
  usleep(hold * 1000);
  post(kCGEventLeftMouseUp, b);
  double up2 = ms();
  printf("down1 0 ms, up1 %.0f ms, down2 %.0f ms (%.0f ms after up1), up2 %.0f ms (held %.0f ms)\n",
         up1, down2, down2 - up1, up2, up2 - down2);
  return 0;
}
