#include "sdf_experiment.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include <cstdlib>
#if PROFILING
#include <iostream>
#endif

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


const int FloorWidth = 100;
const int FloorHeight = 100;
const int SceneObjects = 4;
const int ObjectsCount = FloorWidth * FloorHeight + SceneObjects;
std::vector<ShapeInfo> Objects;
ShapeInfo* Tangerine = nullptr;
ShapeInfo* Lime = nullptr;
ShapeInfo* Onion = nullptr;


#if PROFILING
GLuint FrameStartTime;
GLuint FrameEndTime;
GLuint DrawTimeQueries[ObjectsCount];
GLint GetQueryValue(GLuint Id, GLenum Param)
{
	GLint Value = 0;
	glGetQueryObjectiv(Id, Param, &Value);
	return Value;
}
#endif


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
	glClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);
	glDepthRange(1.0, 0.0);

#if PROFILING
	glGenQueries(1, &FrameStartTime);
	glGenQueries(1, &FrameEndTime);
	glGenQueries(ObjectsCount, &DrawTimeQueries[0]);
#endif

	Objects.reserve(ObjectsCount);
	Objects.push_back(ShapeInfo(0, TRAN(0.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(1, TRAN(3.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(2, TRAN(0.0, 3.0, 0.0)));
	Objects.push_back(ShapeInfo(3, TRAN(0.0, 0.0, 3.0)));
	Tangerine = &Objects[1];
	Lime = &Objects[2];
	Onion = &Objects[3];
	double OffsetX = -double(FloorWidth) * 2.0 + 10.5;
	double OffsetY = -double(FloorHeight) * 2.0 + 10.5;
	for (int y = 0; y < FloorHeight; ++y)
	{
		for (int x = 0; x < FloorWidth; ++x)
		{
			int Fnord = (y % 2 + x) % 2;
			double WorldX = OffsetX + double(x) * 2.0;
			double WorldY = OffsetY + double(y) * 2.0;
			double WorldZ = (double(rand() % 1000) / 1000.0) * 0.5;
			Objects.push_back(ShapeInfo(4 + Fnord, TRAN(WorldX, WorldY, -2.0 - WorldZ)));
		}
	}

	return StatusCode::PASS;
}


void SDFExperiment::WindowIsDirty()
{

}


void SDFExperiment::Render()
{
#if PROFILING
	glQueryCounter(FrameStartTime, GL_TIMESTAMP);
#endif
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	double Time = glfwGetTime();
	UpdateScreenInfo();

#if 1
	{
		double Hover = (sin(Time * 2.0) + 1.0) / 10.0;
		Tangerine->LocalToWorld = TRAN(3.0, 0.0, Hover) * ROTZ(Time * 2.0);
		Tangerine->WorldToLocal = mat4(inverse(Tangerine->LocalToWorld));
	}
	{
		double Hover = (sin(Time * 2.5) + 1.0) / 10.0;
		Lime->LocalToWorld = TRAN(0.0, 3.0, Hover) * ROTZ(Time * 1.8);
		Lime->WorldToLocal = mat4(inverse(Lime->LocalToWorld));
	}
	{
		double Hover = (sin(Time * 2.7) + 1.0) / 10.0;
		Onion->LocalToWorld = TRAN(0.0, 0.0, 3.0 + Hover);
		Onion->WorldToLocal = mat4(inverse(Onion->LocalToWorld));
	}
#endif

	const vec3 OriginStart = vec3(15.0, 0.0, 0.0);
	const vec3 OriginMiddle = vec3(5.0, 5.0, 0.0);
	const vec3 OriginEnd = vec3(7.0, 7.0, 3.5);
	const float Alpha = min(Time / 5.0, 1.0);

	const vec3 CameraOrigin = mix(mix(OriginStart, OriginMiddle, Alpha), mix(OriginMiddle, OriginEnd, Alpha), Alpha);
	const vec3 CameraFocus = vec3(0.0, 0.0, 0.75);

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
		const float Fnord = 1.0;
		const vec4 LocalCorners[8] = \
		{
			vec4(-Fnord, -Fnord, -Fnord, 1.0),
			vec4(-Fnord,  Fnord, -Fnord, 1.0),
			vec4( Fnord, -Fnord, -Fnord, 1.0),
			vec4( Fnord,  Fnord, -Fnord, 1.0),
			vec4(-Fnord, -Fnord,  Fnord, 1.0),
			vec4(-Fnord,  Fnord,  Fnord, 1.0),
			vec4( Fnord, -Fnord,  Fnord, 1.0),
			vec4( Fnord,  Fnord,  Fnord, 1.0)
		};
		float MinDist;
		float MaxDist;
		vec2 MinClip;
		vec2 MaxClip;
		mat4 LocalToClip = ViewToClip * WorldToView * Objects[i].LocalToWorld;
		for (int c = 0; c < 8; ++c)
		{
			vec4 WorldCorner = Objects[i].LocalToWorld * LocalCorners[c];
			vec4 ClipCorner = LocalToClip * LocalCorners[c];
			vec2 Clipped = vec2(ClipCorner.xy) / ClipCorner.w;
			float Dist = distance(vec3(WorldCorner.xyz), CameraOrigin);
			if (c == 0)
			{
				MinDist = Dist;
				MaxDist = Dist;
				MinClip = Clipped;
				MaxClip = Clipped;
			}
			else
			{
				MinDist = min(MinDist, Dist);
				MaxDist = max(MaxDist, Dist);
				MinClip = min(MinClip, Clipped);
				MaxClip = max(MaxClip, Clipped);
			}
		}
		
		{
			const size_t Vectors = 2;
			vec4 BufferData[Vectors] = { vec4(MinClip, MaxClip), vec4(MinDist, MaxDist, 0.0, 0.0) };
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
#if PROFILING
		glBeginQuery(GL_TIME_ELAPSED, DrawTimeQueries[i]);
#endif
		glDrawArrays(GL_TRIANGLES, 0, 6);
#if PROFILING
		glEndQuery(GL_TIME_ELAPSED);
#endif
	}
#if PROFILING
	glQueryCounter(FrameEndTime, GL_TIMESTAMP);
	{
		GLint ElapsedFrameTimeNS = GetQueryValue(FrameEndTime, GL_QUERY_RESULT) - GetQueryValue(FrameStartTime, GL_QUERY_RESULT);
		GLint TotalDrawTimeNS = 0;
		for (int i = 0; i < ObjectsCount; ++i)
		{
			TotalDrawTimeNS += GetQueryValue(DrawTimeQueries[i], GL_QUERY_RESULT);
		}
		std::cout << "GPU Times:\n"
			<< " -   Total Draw: " << double(TotalDrawTimeNS) * 1e-6 << " ms\n"
			<< " - Average Draw: " << double(TotalDrawTimeNS) * 1e-6 / double(ObjectsCount) << " ms\n"
			<< " -  Total Frame: " << double(ElapsedFrameTimeNS) * 1e-6 << " ms\n";
			//<< " - Approx. Idle: " << double(ElapsedFrameTimeNS - TotalDrawTimeNS) * 1e-6 << " ms\n";
	}
#endif
}
