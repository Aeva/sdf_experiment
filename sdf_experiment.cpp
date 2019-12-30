#include "sdf_experiment.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include "lodepng.h"
#include <cstdlib>
#include <iostream>
#include "shaders/defs.glsl"

using namespace glm;

ShaderPipeline DepthShader;
ShaderPipeline ColorShader;
Buffer ScreenInfo;
Buffer ViewInfo;
Buffer AllObjects;

GLuint DepthPass;
GLuint DepthBuffer;
GLuint ObjectIdBuffer;

#if ENABLE_RESOLUTION_SCALING
const float ResolutionScale = 0.5;
#endif //ENABLE_RESOLUTION_SCALING


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


struct ViewInfoUpload
{
	mat4 WorldToView;
	mat4 ViewToWorld;
	mat4 ViewToClip;
	mat4 ClipToView;
	vec4 CameraOrigin;
};


struct TerrainInfo
{
	double Height;

	TerrainInfo(double InHeight)
		: Height(InHeight)
	{}
};


const int FloorWidth = 100;
const int FloorHeight = 100;
const int FloorArea = FloorWidth * FloorHeight;
const int SceneObjects = 4;
const int Trees = 100;
const int ObjectsCount = FloorArea + SceneObjects + Trees;
std::vector<TerrainInfo> MapData;
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


void UpdateScreenInfo(bool bResolutionScaling)
{
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
#if ENABLE_RESOLUTION_SCALING
	if (bResolutionScaling)
	{
		ScreenWidth = ceil(ScreenWidth * ResolutionScale);
		ScreenHeight = ceil(ScreenHeight * ResolutionScale);
	}
#endif //ENABLE_RESOLUTION_SCALING
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


StatusCode ReadMapFile(const char* FileName, std::vector<unsigned char>* ImageData)
{
	unsigned ImageWidth;
	unsigned ImageHeight;
	unsigned Error = lodepng::decode(*ImageData, ImageWidth, ImageHeight, FileName);
	if (Error)
	{
		std::cout \
			<< "Failed to read " << FileName <<"!\n"
			<< " - Reason: PNG decode error:\n"
			<< " - [" << Error << "] " << lodepng_error_text(Error) << "\n";
		return StatusCode::FAIL;
	}
	if (ImageWidth != FloorWidth || ImageHeight != FloorHeight)
	{
		std::cout \
			<< "Failed to read " << FileName << "!\n"
			<< " - Reason: Image not expected sive.\n";
		return StatusCode::FAIL;
	}
	return StatusCode::PASS;
}


int MapIndex(int x, int y)
{
	x = max(min(x, FloorWidth - 1), 0);
	y = max(min(y, FloorHeight - 1), 0);
	return FloorWidth * y + x;
}


StatusCode ReadMapData()
{
	std::vector<unsigned char> HeightData;
	std::vector<unsigned char> TerrainData;
	const char* HeightFile = "heightmap.png";
	const char* TerrainFile = "terrain.png";
	RETURN_ON_FAIL(ReadMapFile(HeightFile, &HeightData));
	RETURN_ON_FAIL(ReadMapFile(TerrainFile, &TerrainData));

	MapData.reserve(FloorArea);
	for (int i = 0; i < FloorArea; ++i)
	{
		const double Alpha = double(HeightData[i * 4]) / 255.0;
		const double Height = mix(-3.5, 5.0, Alpha);
		MapData.emplace_back(Height);
	}

	return StatusCode::PASS;
}


void AllocateRenderTargets(bool bErase=false)
{
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
#if ENABLE_RESOLUTION_SCALING
	ScreenWidth = ceil(ScreenWidth * ResolutionScale);
	ScreenHeight = ceil(ScreenHeight * ResolutionScale);
#endif //ENABLE_RESOLUTION_SCALING

	if (bErase)
	{
		glDeleteFramebuffers(1, &DepthPass);
		glDeleteTextures(1, &DepthBuffer);
		glDeleteTextures(1, &ObjectIdBuffer);
	}

	glCreateTextures(GL_TEXTURE_2D, 1, &DepthBuffer);
	glTextureStorage2D(DepthBuffer, 1, GL_DEPTH_COMPONENT32F, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(DepthBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

	glCreateTextures(GL_TEXTURE_2D, 1, &ObjectIdBuffer);
	glTextureStorage2D(ObjectIdBuffer, 1, GL_R32I, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

	glCreateFramebuffers(1, &DepthPass);
	glNamedFramebufferTexture(DepthPass, GL_DEPTH_ATTACHMENT, DepthBuffer, 0);
	glNamedFramebufferTexture(DepthPass, GL_COLOR_ATTACHMENT0, ObjectIdBuffer, 0);
}


StatusCode SDFExperiment::Setup(GLFWwindow* Window)
{
	RETURN_ON_FAIL(DepthShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/depth.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/depth.fs.glsl"} }));

	RETURN_ON_FAIL(ColorShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/color.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/color.fs.glsl"} }));

	// cheese opengl into letting us draw triangles without any data
	GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	glDepthFunc(GL_GREATER);
	glClearDepth(0.0);
	glClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);
	glDepthRange(1.0, 0.0);

#if PROFILING
	glGenQueries(1, &FrameStartTime);
	glGenQueries(1, &FrameEndTime);
	glGenQueries(1, &DrawTime);
#endif

	AllocateRenderTargets();

	Objects.reserve(ObjectsCount);
	Objects.push_back(ShapeInfo(SHAPE_ORIGIN, vec3(1.0), TRAN(0.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(SHAPE_X_AXIS, vec3(1.0), TRAN(3.0, 0.0, 0.0)));
	Objects.push_back(ShapeInfo(SHAPE_Y_AXIS, vec3(1.0), TRAN(0.0, 3.0, 0.0)));
	Objects.push_back(ShapeInfo(SHAPE_Z_AXIS, vec3(1.0), TRAN(0.0, 0.0, 3.0)));

#if USE_SCENE == SCENE_RANDOM_FOREST
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

			const int PaintFn = bIsRiver ? SHAPE_WATER_CUBE_1 + int(bIsOdd) : SHAPE_GRASS_CUBE_1 + int(bIsOdd);
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
		Objects.push_back(ShapeInfo(SHAPE_TREE, vec3(2.0, 2.0, 4.0), TRAN(WorldPos.x, WorldPos.y, OffsetZ)));
	}

#elif USE_SCENE == SCENE_HEIGHTMAP
	RETURN_ON_FAIL(ReadMapData());
	bool bToggle = false;
	const double WorldOffsetX = -double(FloorWidth) * 0.5;
	const double WorldOffsetY = -double(FloorHeight) * 0.5;
	for (int y = 0; y < FloorHeight; ++y)
	{
		for (int x = 0; x < FloorWidth; ++x)
		{
			const TerrainInfo Terrain = MapData[MapIndex(x, y)];
			const bool bIsRiver = false;

			const double WorldX = double(x) + WorldOffsetX;
			const double WorldY = double(y) + WorldOffsetY;
			const double WorldZ = Terrain.Height;

			const int PaintFn = bIsRiver ? SHAPE_WATER_CUBE_1 + int(bToggle) : SHAPE_GRASS_CUBE_1 + int(bToggle);
			
			Objects.push_back(ShapeInfo(PaintFn, vec3(1.0, 1.0, 1.0), TRAN(WorldX, WorldY, WorldZ)));
			bToggle = !bToggle;
		}
		bToggle = !bToggle;
	}


#endif // USE_SCENE

	Tangerine = &Objects[1];
	Lime = &Objects[2];
	Onion = &Objects[3];

	return StatusCode::PASS;
}


void SDFExperiment::WindowIsDirty()
{
	AllocateRenderTargets(true);
}


void SDFExperiment::Render()
{
#if PROFILING
	glQueryCounter(FrameStartTime, GL_TIMESTAMP);
#endif
	//glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	double Time = glfwGetTime();

#if ENABLE_HOVERING_SHAPES
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
	//const vec3 OriginEnd = vec3(5.0, 5.0, 3.0);
	const float Alpha = min(Time / 5.0, 1.0);

	const vec3 CameraOrigin = mix(mix(OriginStart, OriginMiddle, Alpha), mix(OriginMiddle, OriginEnd, Alpha), Alpha);
	const vec3 CameraFocus = vec3(0.0, 0.0, 0.75);
	//const vec3 CameraFocus = vec3(3.0, 0.0, 0.5);

	const mat4 WorldToView = lookAt(CameraOrigin, CameraFocus, vec3(0.0, 0.0, 1.0));
	const mat4 ViewToWorld = inverse(WorldToView);

	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
	const float AspectRatio = ScreenWidth / ScreenHeight;
	const mat4 ViewToClip = infinitePerspective(radians(45.f), AspectRatio, 1.0f);
	const mat4 ClipToView = inverse(ViewToClip);

	{
		ViewInfoUpload BufferData = {
			WorldToView,
			ViewToWorld,
			ViewToClip,
			ClipToView,
			vec4(CameraOrigin, float(Time))
		};
		ViewInfo.Upload((void*)&BufferData, sizeof(BufferData));
	}

	glEnable(GL_DEPTH_TEST);
	glBindFramebuffer(GL_FRAMEBUFFER, DepthPass);
	glBindTextureUnit(1, 0);
	glBindTextureUnit(2, 0);
	DepthShader.Activate();
	glClear(GL_DEPTH_BUFFER_BIT);
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	ViewInfo.Bind(GL_UNIFORM_BUFFER, 2);
	UpdateScreenInfo(true);

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
		float MinViewZ;
		float MaxViewZ;
		float MinDist;
		float MaxDist;
		vec2 MinClip;
		vec2 MaxClip;
		mat4 LocalToClip = ViewToClip * WorldToView * Objects[i].LocalToWorld;
		mat4 LocalToView = WorldToView * Objects[i].LocalToWorld;
		for (int c = 0; c < 8; ++c)
		{
			vec4 ViewCorner = LocalToView * LocalCorners[c];
			vec4 ClipCorner = LocalToClip * LocalCorners[c];
			vec2 Clipped = vec2(ClipCorner.xy) / ClipCorner.w;
			float Dist = length(vec3(ViewCorner.xyz));
			if (c == 0)
			{
				MinDist = Dist;
				MaxDist = Dist;
				MinClip = Clipped;
				MaxClip = Clipped;
				MinViewZ = ViewCorner.z;
				MaxViewZ = ViewCorner.z;
			}
			else
			{
				MinDist = min(MinDist, Dist);
				MaxDist = max(MaxDist, Dist);
				MinClip = min(MinClip, Clipped);
				MaxClip = max(MaxClip, Clipped);
				MinViewZ = max(MinViewZ, ViewCorner.z);
				MaxViewZ = max(MaxViewZ, ViewCorner.z);
			}
		}
		if (MinDist >= 1.0 && MinClip.x <= 1.0 && MinClip.y <= 1.0 && MaxClip.x >= -1.0 && MaxClip.y >= -1.0 && MaxViewZ < 0.0)
		{
			VisibleObjects.emplace_back(Objects[i], vec4(MinClip, MaxClip), vec2(MinDist, MaxDist));
		}
	}

	// Upload the information for all visible objects.
	const int VisibleObjectsCount = VisibleObjects.size();
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

	glDisable(GL_DEPTH_TEST);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glBindTextureUnit(1, DepthBuffer);
	glBindTextureUnit(2, ObjectIdBuffer);
	ColorShader.Activate();
#if ENABLE_RESOLUTION_SCALING
	if (ResolutionScale < 1.0)
	{
		UpdateScreenInfo(false);
	}
#endif //ENABLE_RESOLUTION_SCALING

	glDrawArrays(GL_TRIANGLES, 0, 6);


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
