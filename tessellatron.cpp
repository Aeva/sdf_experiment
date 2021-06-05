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


StatusCode Tessellatron::Setup()
{
	RETURN_ON_FAIL(TestShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellation_test/test.vs.glsl"},
		  {GL_TESS_CONTROL_SHADER, "shaders/tessellation_test/test.tcs.glsl"},
		  {GL_TESS_EVALUATION_SHADER, "shaders/tessellation_test/test.tes.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellation_test/test.fs.glsl"} },
		"Tessellation Test"));

	// Cheese opengl into letting us draw triangles without any data.
	GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

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
	glClear(GL_COLOR_BUFFER_BIT);

	glPatchParameteri(GL_PATCH_VERTICES, 3);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	glDrawArrays(GL_PATCHES, 0, 3);

	glPopDebugGroup();
}
