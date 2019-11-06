#include "sdf_experiment.h"
#include "glm/glm.hpp"
#include "glm/ext.hpp"

using namespace glm;

ShaderPipeline SplatShader;
Buffer ScreenInfo;
Buffer ViewInfo;
Buffer CameraInfo;
Buffer ClipInfo;


void UpdateScreenInfo()
{
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	float ScaleX;
	float ScaleY;
	GetDPIScale(&ScaleX, &ScaleY);
	GLfloat BufferData[8] = {
		ScreenWidth,
		ScreenHeight,
		1.0f / ScreenWidth,
		1.0f / ScreenHeight,
		ScaleX,
		ScaleY,
		1.0f / ScaleX,
		1.0f / ScaleY
	};
	ScreenInfo.Upload((void*)&BufferData, sizeof(BufferData));
	glViewport(0, 0, ScreenWidth, ScreenHeight);
}


StatusCode SDFExperiment::Setup(GLFWwindow* Window)
{
	RETURN_ON_FAIL(SplatShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/splat.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/splat.fs.glsl"} }));

	// cheese opengl into letting us draw triangles without any data
	GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	return StatusCode::PASS;
}


void SDFExperiment::WindowIsDirty()
{

}


void SDFExperiment::Render()
{
	double Time = glfwGetTime();
	UpdateScreenInfo();

	const vec3 CameraStart = vec3(0.0, -20.0, 0.0);
	const vec3 CameraEnd = vec3(0.0, -5.0, 15.0);
	const float Alpha = min(Time / 5.0, 1.0);

	const vec3 CameraOrigin = mix(CameraStart, CameraEnd, Alpha);
	const mat4 WorldToView = lookAt(CameraOrigin, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
	const mat4 ViewToWorld = inverse(WorldToView);

	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	const float AspectRatio = ScreenWidth / ScreenHeight;
	const mat4 ViewToClip = perspective(radians(45.f), AspectRatio, 10.0f, 1000.0f);
	const mat4 ClipToView = inverse(ViewToClip);

	{
		const size_t Matrices = 4;
		mat4 BufferData[Matrices] = { WorldToView, ViewToWorld, ViewToClip, ClipToView };
		ViewInfo.Upload((void*)&BufferData, sizeof(mat4) * Matrices);
	}

	{
		const size_t Vectors = 1;
		vec4 BufferData[1] = { vec4(CameraOrigin, 1.0) };
		CameraInfo.Upload((void*)&BufferData, sizeof(vec4) * Vectors);
	}

	{
		const size_t Vectors = 1;
		vec4 BufferData[1] = { vec4(-1.0, -1.0, 1.0, 1.0) };
		ClipInfo.Upload((void*)&BufferData, sizeof(vec4) * Vectors);
	}

	SplatShader.Activate();
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	ViewInfo.Bind(GL_UNIFORM_BUFFER, 2);
	CameraInfo.Bind(GL_UNIFORM_BUFFER, 3);
	ClipInfo.Bind(GL_UNIFORM_BUFFER, 4);
	glDrawArrays(GL_TRIANGLES, 0, 6);
}
