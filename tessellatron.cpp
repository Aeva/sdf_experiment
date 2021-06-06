#include "tessellatron.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include "shaders/defs.glsl"
#include "lodepng.h"
#include <cstdlib>
#include <iostream>


ShaderPipeline TestShader;

const GLuint FinalPass = 0;


#define USE_TESSELATION 1


StatusCode Tessellatron::Setup()
{
#if USE_TESSELATION
	RETURN_ON_FAIL(TestShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellation_test/test.vs.glsl"},
		  {GL_TESS_CONTROL_SHADER, "shaders/tessellation_test/test.tcs.glsl"},
		  {GL_TESS_EVALUATION_SHADER, "shaders/tessellation_test/test.tes.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellation_test/test.fs.glsl"} },
		"Tessellation Test"));
#else
	RETURN_ON_FAIL(TestShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellation_test/test.vs.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellation_test/test.fs.glsl"} },
		"Tessellation Test"));
#endif

	// Cheese opengl into letting us draw triangles without any data.
	GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_GREATER);
	glClearDepth(0.0);
	glDepthRange(1.0, 0.0);
	glClipControl(GL_UPPER_LEFT, GL_ZERO_TO_ONE);
	glEnable(GL_CULL_FACE);
	glFrontFace(GL_CCW);
	return StatusCode::PASS;
}


void Tessellatron::WindowIsDirty()
{

}


void Tessellatron::Render(const int FrameCounter)
{
	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Tessellation Test Pass");
	glBindFramebuffer(GL_FRAMEBUFFER, FinalPass);

	TestShader.Activate();
	glClearColor(0.25, 0.25, 0.25, 1.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

#if USE_TESSELATION
	glPatchParameteri(GL_PATCH_VERTICES, 3);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	glDrawArrays(GL_PATCHES, 0, 20 * 3);
#else
	glDrawArrays(GL_TRIANGLES, 0, 20 * 3);
#endif

	glPopDebugGroup();
}
