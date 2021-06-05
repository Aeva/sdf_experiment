#ifndef SDF_EXPERIMENT_DOT_H
#define SDF_EXPERIMENT_DOT_H

#include "glue/errors.h"
#include "glue/gl_boilerplate.h"


namespace Tessellatron
{
	StatusCode Setup();
	void WindowIsDirty();
	void Render(const int FrameCounter);
}

#endif
