#pragma once
#include <math.h>
typedef struct { double x,y,width,height; } IDCPanelRect;
static inline IDCPanelRect IDCFullPanel(double width,double height,double keyboard) {
    if (!isfinite(width) || !isfinite(height) || !isfinite(keyboard) || width<=0 || height<=0) return (IDCPanelRect){0,0,0,0};
    return (IDCPanelRect){0,0,width,fmax(1,height-fmax(0,fmin(keyboard,height-1)))};
}
