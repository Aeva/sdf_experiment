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
Buffer AllObjects;


struct ShapeInfo
{
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	vec3 AABB;
	int ShapeFn;

	ShapeInfo(int InShapeFn, vec3 InAABB, dmat4 InLocalToWorld)
		: LocalToWorld(mat4(InLocalToWorld))
		, WorldToLocal(mat4(inverse(InLocalToWorld)))
		, AABB(InAABB)
		, ShapeFn(InShapeFn)
	{}
};


struct ShapeUploadInfo
{
	vec4 ClipBounds; // (MinX, MinY, MaxX, MaxY)
	vec4 DepthRange; // (Min, Max, 0.0, 0.0)
	vec4 ShapeParams; // (AABB Extent, ShapeFn)
	mat4 LocalToWorld;
	mat4 WorldToLocal;

	ShapeUploadInfo()
		: ClipBounds(vec4(0.0))
		, DepthRange(vec4(0.0))
		, ShapeParams(vec4(0.0))
		, LocalToWorld(mat4(0.0))
		, WorldToLocal(mat4(0.0))
	{}

	ShapeUploadInfo(ShapeInfo InShape, vec4 InClipBounds, vec2 InDepthRange)
		: ClipBounds(InClipBounds)
		, DepthRange(vec4(InDepthRange, 0.0, 0.0))
		, ShapeParams(vec4(InShape.AABB, float(InShape.ShapeFn)))
		, LocalToWorld(InShape.LocalToWorld)
		, WorldToLocal(InShape.WorldToLocal)
	{}
};


const int FloorWidth = 100;
const int FloorHeight = 100;
const int SceneObjects = 4;
const int Trees = 100;
const int ObjectsCount = FloorWidth * FloorHeight + SceneObjects + Trees;
std::vector<ShapeInfo> Objects;
ShapeInfo* Tangerine = nullptr;
ShapeInfo* Lime = nullptr;
ShapeInfo* Onion = nullptr;

const size_t AllObjectsSize = sizeof(ShapeInfo) * ObjectsCount;


#if PROFILING
GLuint FrameStartTime;
GLuint FrameEndTime;
GLuint DrawTime;
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
	glClearColor(0.729, 0.861, 0.951, 1.0);
	glClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);
	glDepthRange(1.0, 0.0);

#if PROFILING
	glGenQueries(1, &FrameStartTime);
	glGenQueries(1, &FrameEndTime);
	glGenQueries(1, &DrawTime);
#endif

	Objects.reserve(ObjectsCount);
	Objects.push_back(ShapeInfo(0, vec3(1.0), TRAN(0.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(1, vec3(1.0), TRAN(3.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(2, vec3(1.0), TRAN(0.0, 3.0, 0.0)));
	Objects.push_back(ShapeInfo(3, vec3(1.0), TRAN(0.0, 0.0, 3.0)));

	const double OffsetX = -double(FloorWidth) * 2.0 + 20.5;
	const double OffsetY = -double(FloorHeight) * 2.0 + 20.5;
	const vec2 RiverCenter = vec2(7.5, 7.5);
	const double TileSize = 1.0;
	bool bIsOdd = false;
	for (double y = 0; y < FloorHeight; y += TileSize)
	{
		for (double x = 0; x < FloorWidth; x += TileSize)
		{
			const double WorldX = x * 2.0 + OffsetX;
			const double WorldY = y * 2.0 + OffsetY;

			const double Distance = distance(RiverCenter, vec2(WorldX, WorldY));
			const bool bIsRiver = Distance > 12.0 && Distance < 25.0;

			const int PaintFn = bIsRiver ? 6 + int(bIsOdd) : 4 + int(bIsOdd);
			const double Turbulance = bIsRiver ? 0.25 : 0.5;
			const double Offset = bIsRiver ? 0.5 : 0.0;

			const double WorldZ = (double(rand() % 1000) / 1000.0) * Turbulance + Offset;
			Objects.push_back(ShapeInfo(PaintFn, vec3(TileSize, TileSize, 1.0), TRAN(WorldX, WorldY, -2.0 - WorldZ)));
			bIsOdd = !bIsOdd;
		}
		bIsOdd = !bIsOdd;
	}

	for (int t = 0; t < Trees; ++t)
	{
		vec2 WorldPos = vec2(0.0, 0.0);
		while (distance(RiverCenter, WorldPos) < 34.0)
		{
			const double RandA = (double(rand() % 1000) / 1000.0) * -100.0;
			const double RandB = (double(rand() % 1000) / 1000.0) * -100.0;
			WorldPos = vec2(RandA, RandB);
		}
		const double TreeHeight = 10.0;
		const double ExtentZ = TreeHeight * 0.5;
		const double OffsetZ = ExtentZ - 2.0;
		Objects.push_back(ShapeInfo(8, vec3(2.0, 2.0, 4.0), TRAN(WorldPos.x, WorldPos.y, OffsetZ)));
	}

	Tangerine = &Objects[1];
	Lime = &Objects[2];
	Onion = &Objects[3];

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
		double Hover = (sin(Time * 2.0) + 1.0) / 2.5;
		Tangerine->LocalToWorld = TRAN(3.0, 0.0, Hover) * ROTZ(Time * 2.0);
		Tangerine->WorldToLocal = mat4(inverse(Tangerine->LocalToWorld));
	}
	{
		double Hover = (sin(Time * 2.5) + 1.0) / 2.5;
		Lime->LocalToWorld = TRAN(0.0, 3.0, Hover) * ROTZ(Time * 1.8);
		Lime->WorldToLocal = mat4(inverse(Lime->LocalToWorld));
	}
	{
		double Hover = (sin(Time * 2.7) + 1.0) / 10.0;
		Onion->LocalToWorld = TRAN(0.0, 0.0, 3.0 + Hover);
		Onion->WorldToLocal = mat4(inverse(Onion->LocalToWorld));
	}
#endif

	const vec3 OriginStart = vec3(15.0, 0.0, 2.0);
	const vec3 OriginMiddle = vec3(5.0, 5.0, 2.0);
	const vec3 OriginEnd = vec3(10.0, 10.0, 5.0);
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

	// Update the information for all objects.
	std::vector<ShapeUploadInfo> VisibleObjects;
	VisibleObjects.reserve(ObjectsCount);
	for (int i = 0; i < ObjectsCount; ++i)
	{
		const vec3 Bounds = Objects[i].AABB;
		const vec4 LocalCorners[8] = \
		{
			vec4(-Bounds.x, -Bounds.y, -Bounds.z, 1.0),
			vec4(-Bounds.x,  Bounds.y, -Bounds.z, 1.0),
			vec4( Bounds.x, -Bounds.y, -Bounds.z, 1.0),
			vec4( Bounds.x,  Bounds.y, -Bounds.z, 1.0),
			vec4(-Bounds.x, -Bounds.y,  Bounds.z, 1.0),
			vec4(-Bounds.x,  Bounds.y,  Bounds.z, 1.0),
			vec4( Bounds.x, -Bounds.y,  Bounds.z, 1.0),
			vec4( Bounds.x,  Bounds.y,  Bounds.z, 1.0)
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
		if (MinDist >= 1.0 && MinClip.x <= 1.0 && MinClip.y <= 1.0 && MaxClip.x >= -1.0 && MaxClip.y >= -1.0)
		{
			VisibleObjects.emplace_back(Objects[i], vec4(MinClip, MaxClip), vec2(MinDist, MaxDist));
		}
	}

	// Upload the information for all visible objects.
	const int VisibleObjectsCount = VisibleObjects.size();
	if (VisibleObjectsCount < ObjectsCount)
	{
		VisibleObjects.resize(ObjectsCount);
	}
	AllObjects.Upload((void*)VisibleObjects.data(), sizeof(ShapeUploadInfo) * ObjectsCount);
	AllObjects.Bind(GL_SHADER_STORAGE_BUFFER, 0);

	// Draw all of the everything
	if (VisibleObjectsCount > 0)
	{
#if PROFILING
		glBeginQuery(GL_TIME_ELAPSED, DrawTime);
#endif
		glDrawArraysInstanced(GL_TRIANGLES, 0, 6, VisibleObjectsCount);
#if PROFILING
		glEndQuery(GL_TIME_ELAPSED);
#endif
	}

#if PROFILING
	glQueryCounter(FrameEndTime, GL_TIMESTAMP);
	{
		GLint ElapsedFrameTimeNS = GetQueryValue(FrameEndTime, GL_QUERY_RESULT) - GetQueryValue(FrameStartTime, GL_QUERY_RESULT);
		GLint TotalDrawTimeNS = GetQueryValue(DrawTime, GL_QUERY_RESULT);

		static int FrameCounter = 0;
		FrameCounter += 1;

		const int StatSamples = 500;
		static double TotalDrawTimesNS[StatSamples] = { 0.0 };
		const int Sample = FrameCounter % StatSamples;
		TotalDrawTimesNS[Sample] = double(TotalDrawTimeNS);

		if (Sample == StatSamples - 1)
		{
			double TotalDrawTime = 0.0;
			for (int i = 0; i < StatSamples; ++i)
			{
				TotalDrawTime += TotalDrawTimesNS[i];
			}
			TotalDrawTime /= double(StatSamples);
			TotalDrawTime *= 1e-6;
			std::cout \
				<< "Objects Drawn: " << VisibleObjectsCount << "\n"
				<< "Average GPU Times:\n"
				<< " - All Draws: " << TotalDrawTime << " ms\n"
				<< " - Per Shape: " << TotalDrawTime / double(VisibleObjectsCount) << " ms\n";
		}
	}
#endif
}
