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

Buffer Screen("Screen");
Buffer Camera("Camera");
Buffer Spheres;

const GLuint FinalPass = 0;


struct ScreenUpload
{
	vec4 ScreenSize;
};


struct CameraUpload
{
	mat4 WorldToView;
	mat4 ViewToWorld;
	mat4 ViewToClip;
	mat4 ClipToView;
	vec4 CameraOrigin;
};


#define OBJECT_COUNT 3
struct ObjectUpload
{
	vec4 SphereParams[OBJECT_COUNT];
};


void UpdateScreenInfo()
{
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	ScreenUpload BufferData = {
		vec4(ScreenWidth, ScreenHeight, 1.0f / ScreenWidth, 1.0f / ScreenHeight),
	};
	Screen.Upload((void*)&BufferData, sizeof(BufferData));
	glViewport(0, 0, ScreenWidth, ScreenHeight);
}


StatusCode Tessellatron::Setup()
{
	UpdateScreenInfo();

	RETURN_ON_FAIL(TestShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellation_test/test.vs.glsl"},
		  {GL_TESS_CONTROL_SHADER, "shaders/tessellation_test/test.tcs.glsl"},
		  {GL_TESS_EVALUATION_SHADER, "shaders/tessellation_test/test.tes.glsl"},
		  {GL_GEOMETRY_SHADER, "shaders/tessellation_test/test.gs.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellation_test/test.fs.glsl"} },
		"Tessellation Test"));

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
	UpdateScreenInfo();
}


void Tessellatron::Render(const int FrameCounter)
{
	double Time = glfwGetTime();
	{
		const vec3 CameraOrigin = vec3(0.0, 5.0, 0.0);
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
			vec4(CameraOrigin, Time)
		};
		Camera.Upload((void*)&BufferData, sizeof(BufferData));
	}
	{
		ObjectUpload BufferData;
		double Offset = sin(Time * 1.5) * 0.5 + 0.85;
		BufferData.SphereParams[0] = vec4(Offset, 0.0, 0.0, 1.0);
		BufferData.SphereParams[1] = vec4(-Offset, 0.0, 0.0, 0.9);
		BufferData.SphereParams[2] = vec4(0.0, 0.5, 0.85, -0.9);
		Spheres.Upload((void*)&BufferData, sizeof(BufferData));
	}

	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Tessellation Test Pass");
	glBindFramebuffer(GL_FRAMEBUFFER, FinalPass);

	TestShader.Activate();
	glClearColor(0.25, 0.25, 0.25, 1.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	Screen.Bind(GL_UNIFORM_BUFFER, 1);
	Camera.Bind(GL_UNIFORM_BUFFER, 2);
	Spheres.Bind(GL_UNIFORM_BUFFER, 3);

	glPatchParameteri(GL_PATCH_VERTICES, 3);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	glDrawArraysInstanced(GL_PATCHES, 0, 20 * 3, OBJECT_COUNT);

	glPopDebugGroup();
}
