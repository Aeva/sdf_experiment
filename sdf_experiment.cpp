#include "sdf_experiment.h"
#include "glm/glm.hpp"
#include "glm/ext.hpp"

using namespace glm;

ShaderPipeline SplatShader;
Buffer ScreenInfo;


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
	const mat4 ViewMatrix = lookAt(vec3(0.0, 10.0, 5.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
	//const mat4 InvViewMatrix = inverse(ViewMatrix);

	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	const float AspectRatio = ScreenWidth / ScreenHeight;
	const mat4 PerspectiveMatrix = perspective(radians(45.f), AspectRatio, 10.0f, 1000.0f);
	//const mat4 InvPerspectiveMatrix = inverse(PerspectiveMatrix);

	// AABB for a sphere at (0,0,0) with a radius of 1
	const vec4 Low = vec4(-1.0, -1.0, -1.0, 1.0);
	const vec4 High = vec4(1.0, 1.0, 1.0, 1.0);
	const vec4 Clip1 = PerspectiveMatrix * ViewMatrix * Low;
	const vec4 Clip2 = PerspectiveMatrix * ViewMatrix * High;
#define fnord(op, n) op(Clip1.##n / Clip1.w, Clip2.##n / Clip2.w)
	const vec3 ClipMin = vec3(fnord(min, x), fnord(min, y), fnord(min, z));
	const vec3 ClipMax = vec3(fnord(max, x), fnord(max, y), fnord(max, z));
#undef fnord
	//std::cout << "ClipMin: " << ClipMin.x << ", " << ClipMin.y << ", " << ClipMin.z << "\n";
	//std::cout << "ClipMax: " << ClipMax.x << ", " << ClipMax.y << ", " << ClipMax.z << "\n";
	
	UpdateScreenInfo();

	SplatShader.Activate();
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	glDrawArrays(GL_TRIANGLES, 0, 3);
}
