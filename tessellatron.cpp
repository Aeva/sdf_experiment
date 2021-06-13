#include "tessellatron.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include "shaders/defs.glsl"
#include "lodepng.h"
#include <cstdlib>
#include <iostream>

using namespace glm;


ShaderPipeline CoarsePass;
ShaderPipeline FinePass;


Buffer Screen("Screen");
Buffer Camera("Camera");
Buffer Spheres("Spheres");
Buffer HeapMeta("Meta Heap");
Buffer HeapTriangles("Triangles Heap");


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


struct HeapMetaUpload
{
	uint MaxSize;
	uint Count;
	uint InstanceCount;
	uint First;
	uint BaseInstance;
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

	RETURN_ON_FAIL(CoarsePass.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellatron/sphere.vs.glsl"},
		  {GL_TESS_CONTROL_SHADER, "shaders/tessellatron/coarse.tcs.glsl"},
		  {GL_TESS_EVALUATION_SHADER, "shaders/tessellatron/coarse.tes.glsl"},
		  {GL_GEOMETRY_SHADER, "shaders/tessellatron/coarse.gs.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellatron/coarse.fs.glsl"} },
		"Coarse Tessellation Shader"));

	RETURN_ON_FAIL(FinePass.Setup(
		{ {GL_VERTEX_SHADER, "shaders/tessellatron/fine.vs.glsl"},
		  {GL_TESS_CONTROL_SHADER, "shaders/tessellatron/fine.tcs.glsl"},
		  {GL_TESS_EVALUATION_SHADER, "shaders/tessellatron/fine.tes.glsl"},
		  {GL_GEOMETRY_SHADER, "shaders/tessellatron/fine.gs.glsl"},
		  {GL_FRAGMENT_SHADER, "shaders/tessellatron/fine.fs.glsl"} },
		"Fine Tessellation Shader"));

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
	{
		uint MaxVertices = 10000 * 3;
		{
			size_t HeapBytes = MaxVertices * sizeof(float) * 4;
			HeapTriangles.Reserve(HeapBytes);
		}
		{
			HeapMetaUpload BufferData;
			BufferData.MaxSize = MaxVertices;
			BufferData.Count = 0;
			BufferData.InstanceCount = 1;
			BufferData.First = 0;
			BufferData.BaseInstance = 0;
			HeapMeta.Upload((void*)&BufferData, sizeof(BufferData));
		}
	}
	{
		glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Coarse Pass");
		glBindFramebuffer(GL_FRAMEBUFFER, FinalPass);

		CoarsePass.Activate();
		glClearColor(0.25, 0.25, 0.25, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		Screen.Bind(GL_UNIFORM_BUFFER, 1);
		Camera.Bind(GL_UNIFORM_BUFFER, 2);
		Spheres.Bind(GL_UNIFORM_BUFFER, 3);

		HeapMeta.Bind(GL_SHADER_STORAGE_BUFFER, 0);
		HeapTriangles.Bind(GL_SHADER_STORAGE_BUFFER, 1);

		glPatchParameteri(GL_PATCH_VERTICES, 3);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		glDrawArraysInstanced(GL_PATCHES, 0, 20 * 3, OBJECT_COUNT);

		glPopDebugGroup();
	}
	{
		glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Coarse Pass");

		FinePass.Activate();
		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
		HeapMeta.Bind(GL_DRAW_INDIRECT_BUFFER);
		glDrawArraysIndirect(GL_PATCHES, (void*)(sizeof(uint)));

		glPopDebugGroup();
	}
}
