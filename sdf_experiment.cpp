#include "sdf_experiment.h"
#include "glm/glm.hpp"
#include "glm/ext.hpp"

using namespace glm;

ShaderPipeline SplatShader;
Buffer ScreenInfo;
Buffer ViewInfo;
Buffer CameraInfo;


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

	//const mat4 WorldToClip = ViewToClip * ViewMatrix;
	//const mat4 ClipToWorld = inverse(WorldToClip);

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
	
	/*
	// AABB for a sphere at (0,0,0) with a radius of 1
	const vec4 Low = vec4(-1.0, -1.0, -1.0, 1.0);
	const vec4 High = vec4(1.0, 1.0, 1.0, 1.0);
	const vec4 Clip1 = WorldToClip * Low;
	const vec4 Clip2 = WorldToClip * High;
#define fnord(op, n) op(Clip1.##n / Clip1.w, Clip2.##n / Clip2.w)
	const vec4 ClipMin = vec4(fnord(min, x), fnord(min, y), fnord(min, z), 1.0);
	const vec4 ClipMax = vec4(fnord(max, x), fnord(max, y), fnord(max, z), 1.0);
#undef fnord
	//std::cout << "ClipMin: " << ClipMin.x << ", " << ClipMin.y << ", " << ClipMin.z << "\n";
	//std::cout << "ClipMax: " << ClipMax.x << ", " << ClipMax.y << ", " << ClipMax.z << "\n";
	*/
	vec4 ClipCorner1 = vec4(-1.0, -1.0, 0.0, 1.0);
	vec4 ClipCorner2 = vec4(1.0, 1.0, 0.0, 1.0);

	vec4 Test1 = ClipToView * ClipCorner1;
	vec4 Test2 = ClipToView * ClipCorner2;
	
	vec3 Test1a = normalize(vec3(Test1.x, Test1.y, 0.0) / Test1.w);
	vec3 Test2a = normalize(vec3(Test2.x, Test2.y, 0.0) / Test2.w);

	SplatShader.Activate();
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	ViewInfo.Bind(GL_UNIFORM_BUFFER, 2);
	CameraInfo.Bind(GL_UNIFORM_BUFFER, 3);
	glDrawArrays(GL_TRIANGLES, 0, 3);
}
