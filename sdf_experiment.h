#ifndef SDF_EXPERIMENT_DOT_H
#define SDF_EXPERIMENT_DOT_H

#include "glue/errors.h"
#include "glue/gl_boilerplate.h"


namespace SDFExperiment
{
	StatusCode Setup(GLFWwindow* Window);
	void WindowIsDirty();
	void Render();
}

#endif