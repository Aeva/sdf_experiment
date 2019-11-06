#include "sdf_experiment.h"
#include "glm/glm.hpp"
#include "glm/ext.hpp"

using namespace glm;

ShaderPipeline SplatShader;
Buffer ScreenInfo;
Buffer ViewInfo;
Buffer CameraInfo;
Buffer ClipInfo;
Buffer ObjectInfo;


struct ShapeInfo
{
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	int ShapeFn;

	ShapeInfo(int InShapeFn, dmat4 InLocalToWorld)
		: LocalToWorld(mat4(InLocalToWorld))
		, WorldToLocal(mat4(inverse(InLocalToWorld)))
		, ShapeFn(InShapeFn)
	{}
};


const int ObjectsCount = 3;
const ShapeInfo Objects[ObjectsCount] = \
{
	ShapeInfo(0, TRAN(-4.0, 0.0, 0.0)),
	ShapeInfo(1, TRAN(0.0, 0.0, 0.0)),
	ShapeInfo(2, TRAN(4.0, 0.0, 0.0))
};


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

	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_GREATER);
	glClearDepth(0.0);
	glClearColor(0.1, 0.1, 0.1, 1.0);
	glClipControl(GL_UPPER_LEFT, GL_ZERO_TO_ONE);
	glDepthRange(1.0, 0.0);

	return StatusCode::PASS;
}


void SDFExperiment::WindowIsDirty()
{

}


void SDFExperiment::Render()
{
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	double Time = glfwGetTime();
	UpdateScreenInfo();

	const vec3 OriginStart = vec3(10.0, -2.0, 0.0);
	const vec3 OriginMiddle = vec3(0.0, -20.0, 0.0);
	const vec3 OriginEnd = vec3(-10.0, -2.0, 0.0);
	const vec3 FocusStart = vec3(4.0, 0.0, 0.0);
	const vec3 FocusEnd = vec3(-4.0, 0.0, 0.0);
	const float Alpha = min(Time / 5.0, 1.0);

	const vec3 CameraOrigin = mix(mix(OriginStart, OriginMiddle, Alpha), mix(OriginMiddle, OriginEnd, Alpha), Alpha);
	const vec3 CameraFocus = mix(FocusStart, FocusEnd, Alpha);
	const mat4 WorldToView = lookAt(CameraOrigin, CameraFocus, vec3(0.0, 0.0, 1.0));
	const mat4 ViewToWorld = inverse(WorldToView);

	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	const float AspectRatio = ScreenWidth / ScreenHeight;
	const mat4 ViewToClip = infinitePerspective(radians(45.f), AspectRatio, 1.0f);
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

	SplatShader.Activate();
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	ViewInfo.Bind(GL_UNIFORM_BUFFER, 2);
	CameraInfo.Bind(GL_UNIFORM_BUFFER, 3);

	for (int i = 0; i < ObjectsCount; ++i)
	{
		{
			const size_t Vectors = 1;
			vec4 BufferData[1] = { vec4(-1.0, -1.0, 1.0, 1.0) };
			ClipInfo.Upload((void*)&BufferData, sizeof(vec4) * Vectors);
			ClipInfo.Bind(GL_UNIFORM_BUFFER, 4);
		}
		{
			const size_t Bytes = sizeof(mat4) * 3;
			char BufferData[Bytes] = { 0 };
			void* BufferDataPtr = (void*)&BufferData;
			{
				mat4* LocalToWorld = reinterpret_cast<mat4*>(BufferDataPtr);
				mat4* WorldToLocal = LocalToWorld + 1;
				int32* ShapeFn = reinterpret_cast<int32*>(WorldToLocal + 1);
				*LocalToWorld = Objects[i].LocalToWorld;
				*WorldToLocal = Objects[i].WorldToLocal;
				*ShapeFn = Objects[i].ShapeFn;
			}
			ObjectInfo.Upload(BufferDataPtr, Bytes);
			ObjectInfo.Bind(GL_UNIFORM_BUFFER, 5);
		}
		glDrawArrays(GL_TRIANGLES, 0, 6);
	}
}
