#include "tessellatron.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include "shaders/defs.glsl"
#include "lodepng.h"
#include <cstdlib>
#include <iostream>

using namespace glm;


ShaderPipeline TestShader;

Buffer Camera("Camera");

const GLuint FinalPass = 0;


#define USE_TESSELATION 1


struct CameraUpload
{
	mat4 WorldToView;
	mat4 ViewToWorld;
	mat4 ViewToClip;
	mat4 ClipToView;
	vec4 CameraOrigin;
};


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
	glClipControl(GL_LOWER_LEFT, GL_NEGATIVE_ONE_TO_ONE);
	glEnable(GL_CULL_FACE);
	glFrontFace(GL_CCW);
	return StatusCode::PASS;
}


void Tessellatron::WindowIsDirty()
{

}


void Tessellatron::Render(const int FrameCounter)
{
	{
		const vec3 CameraOrigin = vec3(2.0, 2.0, 2.0);
		const vec3 CameraFocus = vec3(0.0, 0.0, 0.0);
		const vec3 UpVector = vec3(0.0, 0.0, 1.0);
		const mat4 WorldToView = lookAt(CameraOrigin, CameraFocus, UpVector);
		const mat4 ViewToWorld = inverse(WorldToView);

		float ScreenWidth;
		float ScreenHeight;
		GetScreenSize(&ScreenWidth, &ScreenHeight);

		const float AspectRatio = ScreenWidth / ScreenHeight;
		const mat4 ViewToClip = infinitePerspective(radians(45.f), AspectRatio, 1.0f);
		const mat4 ClipToView = inverse(ViewToClip);

		CameraUpload BufferData = {
			WorldToView,
			ViewToWorld,
			ViewToClip,
			ClipToView,
			vec4(CameraOrigin, 0.0)
		};
		Camera.Upload((void*)&BufferData, sizeof(BufferData));
	}

	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Tessellation Test Pass");
	glBindFramebuffer(GL_FRAMEBUFFER, FinalPass);

	TestShader.Activate();
	glClearColor(0.25, 0.25, 0.25, 1.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	Camera.Bind(GL_UNIFORM_BUFFER, 2);

#if USE_TESSELATION
	glPatchParameteri(GL_PATCH_VERTICES, 3);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	glDrawArrays(GL_PATCHES, 0, 20 * 3);
#else
	glDrawArrays(GL_TRIANGLES, 0, 20 * 3);
#endif

	glPopDebugGroup();
}
