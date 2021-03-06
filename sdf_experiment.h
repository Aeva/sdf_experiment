#ifndef SDF_EXPERIMENT_DOT_H
#define SDF_EXPERIMENT_DOT_H

#include "glue/errors.h"
#include "glue/gl_boilerplate.h"


namespace SDFExperiment
{
	StatusCode Setup();
	void WindowIsDirty();
	void Render(const int FrameCounter);
}


#define TRAN(X, Y, Z) mat4( \
    1.0, 0.0, 0.0, 0.0, \
    0.0, 1.0, 0.0, 0.0, \
    0.0, 0.0, 1.0, 0.0, \
    X,   Y,   Z,   1.0)


#define ROTX(A) mat4( \
    1.0, 0.0,    0.0,     0.0, \
    0.0, cos(A), sin(A), 0.0, \
    0.0, -sin(A), cos(A),  0.0, \
    0.0, 0.0,    0.0,     1.0)


#define ROTY(A) mat4( \
    cos(A),  0.0, -sin(A), 0.0, \
    0.0,     1.0, 0.0,    0.0, \
    sin(A), 0.0, cos(A), 0.0, \
    0.0,     0.0, 0.0,    1.0)


#define ROTZ(A) mat4( \
    cos(A), sin(A), 0.0, 0.0, \
    -sin(A), cos(A),  0.0, 0.0, \
    0.0,    0.0,     1.0, 0.0, \
    0.0,    0.0,     0.0, 1.0)

#endif
