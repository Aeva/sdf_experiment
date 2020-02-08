#include "sdf_experiment.h"
#define GLM_FORCE_SWIZZLE
#include "glm/glm.hpp"
#include "glm/ext.hpp"
#include "shaders/defs.glsl"
#include "lodepng.h"
#include <cstdlib>
#include <iostream>

#if VINE_MODE
#include <stdio.h>
#endif // VINE_MODE

#if PROFILING
#include "glue/logging.h"
#endif //PROFILING

using namespace glm;

ShaderPipeline DepthShader;
ShaderPipeline GloomShader;
ShaderPipeline ColorShader;

Buffer ScreenInfo("ScreenInfo");
Buffer ViewInfo("ViewInfo");
Buffer VisibleObjectsBuffer("VisibleObjectsBuffer");
Buffer ShadowCastersBuffer("ShadowCastersBuffer");

GLuint DepthPass;
GLuint DepthBuffer;
GLuint ObjectIdBuffer;

GLuint GloomPass;
GLuint GloomBuffer;

#if VINE_MODE
GLuint ColorPass;
GLuint ColorBuffer;
#else
const GLuint ColorPass = 0;
#endif // VINE_MODE

#if ENABLE_RESOLUTION_SCALING
const float ResolutionScale = 0.5;
#endif //ENABLE_RESOLUTION_SCALING


#if ENABLE_LIGHT_TRANSMISSION
#define GLOOM_BUFFER_FORMAT GL_RGB8
#else
#define GLOOM_BUFFER_FORMAT GL_R8
#endif // ENABLE_LIGHT_TRANSMISSION


struct ShapeInfo
{
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	vec3 AABB;
	int ShapeFn;
	bool bShadowCaster;

	ShapeInfo(int InShapeFn, vec3 InAABB, dmat4 InLocalToWorld, bool bInShadowCaster)
		: LocalToWorld(mat4(InLocalToWorld))
		, WorldToLocal(mat4(inverse(InLocalToWorld)))
		, AABB(InAABB)
		, ShapeFn(InShapeFn)
		, bShadowCaster(bInShadowCaster)
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

	ShapeUploadInfo(ShapeInfo InShape, int VisibleObjectId)
		: ClipBounds(vec4(0.0, 0.0, 0.0, 0.0))
		, DepthRange(vec4(0.0, 0.0, 0.0, float(VisibleObjectId)))
		, ShapeParams(vec4(InShape.AABB, float(InShape.ShapeFn)))
		, LocalToWorld(InShape.LocalToWorld)
		, WorldToLocal(InShape.WorldToLocal)
	{}

	friend bool operator==(const ShapeUploadInfo& LHS, const ShapeUploadInfo& RHS)
	{
		return LHS.ShapeParams == RHS.ShapeParams && LHS.LocalToWorld == RHS.LocalToWorld;
	}
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


std::vector<TerrainInfo> MapData;
std::vector<ShapeInfo> Objects;
ShapeInfo* Tangerine = nullptr;
ShapeInfo* Lime = nullptr;
ShapeInfo* Onion = nullptr;


#if PROFILING
GLuint FrameStartTime;
GLuint FrameEndTime;
GLuint DepthPassTime;
GLuint GloomPassTime;
GLuint ColorPassTime;
GLint GetQueryValue(GLuint Id, GLenum Param)
{
	GLint Value = 0;
	glGetQueryObjectiv(Id, Param, &Value);
	return Value;
}
#endif


void UpdateScreenInfo(bool bResolutionScaling)
{
#if VINE_MODE
	const float ScreenWidth = VineModeWidth;
	const float ScreenHeight = VineModeHeight;
	const float ScaleX = 1.0;
	const float ScaleY = 1.0;
#else
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
#endif // VINE_MODE
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


StatusCode ReadMapFile(const char* FileName, std::vector<unsigned char>* ImageData, const int Width, const int Height)
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
	if (ImageWidth != Width || ImageHeight != Height)
	{
		std::cout \
			<< "Failed to read " << FileName << "!\n"
			<< " - Reason: Image not expected size.\n";
		return StatusCode::FAIL;
	}
	return StatusCode::PASS;
}


int MapIndex(int x, int y, const int Width, const int Height)
{
	x = max(min(x, Width - 1), 0);
	y = max(min(y, Height - 1), 0);
	return Width * y + x;
}


StatusCode ReadMapData(const int Width, const int Height)
{
	std::vector<unsigned char> HeightData;
	std::vector<unsigned char> TerrainData;
	const char* HeightFile = "heightmap.png";
	const char* TerrainFile = "terrain.png";
	RETURN_ON_FAIL(ReadMapFile(HeightFile, &HeightData, Width, Height));
	RETURN_ON_FAIL(ReadMapFile(TerrainFile, &TerrainData, Width, Height));

	const int Area = Width * Height;
	MapData.reserve(Area);
	for (int i = 0; i < Area; ++i)
	{
		const double Alpha = double(HeightData[i * 4]) / 255.0;
		const double Height = mix(-3.5, 5.0, Alpha);
		MapData.emplace_back(Height);
	}

	return StatusCode::PASS;
}


void AllocateRenderTargets(bool bErase=false)
{
#if VINE_MODE
	const float ScreenWidth = VineModeWidth;
	const float ScreenHeight = VineModeHeight;
#else
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
#if ENABLE_RESOLUTION_SCALING
	ScreenWidth = ceil(ScreenWidth * ResolutionScale);
	ScreenHeight = ceil(ScreenHeight * ResolutionScale);
#endif //ENABLE_RESOLUTION_SCALING
#endif // VINE_MODE

	if (bErase)
	{
		glDeleteFramebuffers(1, &DepthPass);
		glDeleteFramebuffers(1, &GloomPass);
#if VINE_MODE
		glDeleteFramebuffers(1, &ColorPass);
#endif // VINE_MODE
		glDeleteTextures(1, &DepthBuffer);
		glDeleteTextures(1, &ObjectIdBuffer);
		glDeleteTextures(1, &GloomBuffer);
#if VINE_MODE
		glDeleteTextures(1, &ColorBuffer);
#endif // VINE_MODE
	}

	glCreateTextures(GL_TEXTURE_2D, 1, &DepthBuffer);
	glTextureStorage2D(DepthBuffer, 1, GL_DEPTH_COMPONENT32F, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(DepthBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(DepthBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glObjectLabel(GL_TEXTURE, DepthBuffer, -1, "DepthBuffer");

	glCreateTextures(GL_TEXTURE_2D, 1, &ObjectIdBuffer);
	glTextureStorage2D(ObjectIdBuffer, 1, GL_R32I, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(ObjectIdBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glObjectLabel(GL_TEXTURE, ObjectIdBuffer, -1, "ObjectIdBuffer");

	glCreateFramebuffers(1, &DepthPass);
	glNamedFramebufferTexture(DepthPass, GL_DEPTH_ATTACHMENT, DepthBuffer, 0);
	glNamedFramebufferTexture(DepthPass, GL_COLOR_ATTACHMENT0, ObjectIdBuffer, 0);
	glObjectLabel(GL_FRAMEBUFFER, DepthPass, -1, "DepthPass");

	glCreateTextures(GL_TEXTURE_2D, 1, &GloomBuffer);
	glTextureStorage2D(GloomBuffer, 1, GLOOM_BUFFER_FORMAT, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(GloomBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(GloomBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(GloomBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(GloomBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glObjectLabel(GL_TEXTURE, GloomBuffer, -1, "GloomBuffer");

	glCreateFramebuffers(1, &GloomPass);
	glNamedFramebufferTexture(GloomPass, GL_DEPTH_ATTACHMENT, DepthBuffer, 0);
	glNamedFramebufferTexture(GloomPass, GL_COLOR_ATTACHMENT0, GloomBuffer, 0);
	glObjectLabel(GL_FRAMEBUFFER, GloomPass, -1, "GloomPass");

#if VINE_MODE
	glCreateTextures(GL_TEXTURE_2D, 1, &ColorBuffer);
	glTextureStorage2D(ColorBuffer, 1, GL_RGB8, int(ScreenWidth), int(ScreenHeight));
	glTextureParameteri(ColorBuffer, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(ColorBuffer, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureParameteri(ColorBuffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTextureParameteri(ColorBuffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glObjectLabel(GL_TEXTURE, ColorBuffer, -1, "ColorBuffer");

	glCreateFramebuffers(1, &ColorPass);
	glNamedFramebufferTexture(ColorPass, GL_COLOR_ATTACHMENT0, ColorBuffer, 0);
	glObjectLabel(GL_FRAMEBUFFER, ColorPass, -1, "ColorPass");
#endif // VINE_MODE
}


StatusCode SDFExperiment::Setup()
{
	RETURN_ON_FAIL(DepthShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/depth.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/depth.fs.glsl"} },
		"Depth"));

	RETURN_ON_FAIL(GloomShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/gloom.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/gloom.fs.glsl"} },
		"Gloom"));

	RETURN_ON_FAIL(ColorShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/color.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/color.fs.glsl"} },
		"Color"));

	// cheese opengl into letting us draw triangles without any data
	GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	glDepthFunc(GL_GREATER);
	glClearDepth(0.0);
	glClipControl(GL_LOWER_LEFT, GL_NEGATIVE_ONE_TO_ONE);
	glDepthRange(1.0, 0.0);
	glFrontFace(GL_CCW);

#if PROFILING
	glGenQueries(1, &FrameStartTime);
	glGenQueries(1, &FrameEndTime);
	glGenQueries(1, &DepthPassTime);
	glGenQueries(1, &GloomPassTime);
	glGenQueries(1, &ColorPassTime);
#endif

	AllocateRenderTargets();

	Objects.reserve(0);
#if USE_SCENE != SCENE_TRANSLUCENTS
	Objects.push_back(ShapeInfo(SHAPE_ORIGIN, vec3(1.0), TRAN(0.0, 0.0, 0.0), true));
	Objects.push_back(ShapeInfo(SHAPE_X_AXIS, vec3(1.0), TRAN(3.0, 0.0, 0.0), true));
	Objects.push_back(ShapeInfo(SHAPE_Y_AXIS, vec3(1.0), TRAN(0.0, 3.0, 0.0), true));
	Objects.push_back(ShapeInfo(SHAPE_Z_AXIS, vec3(1.0), TRAN(0.0, 0.0, 3.0), true));
#endif

	const int FloorWidth = 100;
	const int FloorHeight = 100;
	const int FloorArea = FloorWidth * FloorHeight;
	const int SceneObjects = 4;
	const int Trees = 100;

#if USE_SCENE == SCENE_RANDOM_FOREST
	const double OffsetX = -double(FloorWidth) * 2.0 + 20.5;
	const double OffsetY = -double(FloorHeight) * 2.0 + 20.5;
	const vec2 RiverCenter = vec2(7.5, 7.5);
	const double TileSize = 1.0;
	bool bIsOdd = false;
	srand(1);
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
			Objects.push_back(ShapeInfo(PaintFn, vec3(TileSize, TileSize, 1.0), TRAN(WorldX, WorldY, -2.0 - WorldZ), false));
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
		const float TreeRadius = 2.0;
		const float TreeHalfHeight = 5.0;
		const vec3 TreeExtent = vec3(TreeRadius, TreeRadius, TreeHalfHeight);
		Objects.push_back(ShapeInfo(SHAPE_TREE, TreeExtent, TRAN(WorldPos.x, WorldPos.y, TreeHalfHeight - 1.5), true));
	}

#elif USE_SCENE == SCENE_HEIGHTMAP
	RETURN_ON_FAIL(ReadMapData(FloorWidth, FloorHeight));
	bool bToggle = false;
	const double WorldOffsetX = -double(FloorWidth) * 0.5;
	const double WorldOffsetY = -double(FloorHeight) * 0.5;
	for (int y = 0; y < FloorHeight; ++y)
	{
		for (int x = 0; x < FloorWidth; ++x)
		{
			const TerrainInfo Terrain = MapData[MapIndex(x, y, FloorWidth, FloorHeight)];
			const bool bIsRiver = false;

			const double WorldX = double(x) + WorldOffsetX;
			const double WorldY = double(y) + WorldOffsetY;
			const double WorldZ = Terrain.Height;

			const int PaintFn = bIsRiver ? SHAPE_WATER_CUBE_1 + int(bToggle) : SHAPE_GRASS_CUBE_1 + int(bToggle);
			
			Objects.push_back(ShapeInfo(PaintFn, vec3(0.5, 0.5, 1.0), TRAN(WorldX, WorldY, WorldZ), false));
			bToggle = !bToggle;
		}
		bToggle = !bToggle;
	}

#elif USE_SCENE == SCENE_TRANSLUCENTS
	Objects.push_back(ShapeInfo(SHAPE_WHITE_SLAB, vec3(7.0, 7.0, 0.1), TRAN(0.0, 0.0, 0.0), false));
	Objects.push_back(ShapeInfo(SHAPE_CYAN_SLAB, vec3(2.0, 0.25, 2.0), TRAN(1.3, -1.5, 2.0), true));
	Objects.push_back(ShapeInfo(SHAPE_YELLOW_SLAB, vec3(2.0, 0.25, 2.0), TRAN(0.0, 0.0, 2.0), true));
	Objects.push_back(ShapeInfo(SHAPE_MAGENTA_SLAB, vec3(2.0, 0.25, 2.0), TRAN(-1.3, 1.5, 2.0), true));


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


void SDFExperiment::Render(const int FrameCounter)
{
#if PROFILING
	glQueryCounter(FrameStartTime, GL_TIMESTAMP);
#endif
#if VINE_MODE
	// Clear the unused backbuffer to red to make it easier to spot problems.
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glClearColor(1.0, 0.0, 0.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	double Time = 1.0 / double(VINE_FPS) * double(FrameCounter);
#else
	double Time = glfwGetTime();
#endif // VINE_MODE

#if ENABLE_HOVERING_SHAPES && USE_SCENE != SCENE_TRANSLUCENTS
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

#if ENABLE_FIXATE_UPON_ORANGE
	const vec3 OriginEnd = vec3(5.0, 5.0, 2.0);
#else
	const vec3 OriginEnd = vec3(10.0, 10.0, 5.0);
#endif // ENABLE_FIXATE_UPON_ORANGE

#if ENABLE_FLY_IN
	const vec3 OriginStart = vec3(15.0, 0.0, 2.0);
	const vec3 OriginMiddle = vec3(5.0, 5.0, 2.0);
	const float Alpha = min(Time / 5.0, 1.0);
	const vec3 CameraOrigin = mix(mix(OriginStart, OriginMiddle, Alpha), mix(OriginMiddle, OriginEnd, Alpha), Alpha);
#else
	const vec3 CameraOrigin = OriginEnd;
#endif // ENABLE_FLY_IN

#if ENABLE_FIXATE_UPON_ORANGE
	const vec3 CameraFocus = vec3(3.0, 0.0, 0.5);
#else
	const vec3 CameraFocus = vec3(0.0, 0.0, 0.75);
#endif // ENABLE_FIXATE_UPON_ORANGE

	const mat4 WorldToView = lookAt(CameraOrigin, CameraFocus, vec3(0.0, 0.0, 1.0));
	const mat4 ViewToWorld = inverse(WorldToView);

#if VINE_MODE
	float ScreenWidth = VineModeWidth;
	float ScreenHeight = VineModeHeight;
#else
	float ScreenWidth;
	float ScreenHeight;
	GetScreenSize(&ScreenWidth, &ScreenHeight);
#endif // VINE_MODE
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

	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Depth");
	glDepthMask(GL_TRUE);
	glEnable(GL_DEPTH_TEST);
	glDisable(GL_CULL_FACE);
	glBindFramebuffer(GL_FRAMEBUFFER, DepthPass);
	glBindTextureUnit(1, 0);
	glBindTextureUnit(2, 0);
	DepthShader.Activate();
	glClear(GL_DEPTH_BUFFER_BIT);
	UpdateScreenInfo(true);

	// Update the information for all objects.
	std::vector<ShapeUploadInfo> VisibleObjects;
	std::vector<ShapeUploadInfo> ShadowCasters;
	const size_t ObjectsCount = Objects.size();
	VisibleObjects.reserve(ObjectsCount);
	ShadowCasters.reserve(ObjectsCount);
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
		const bool bIsVisible = MinDist >= 1.0 && MinClip.x <= 1.0 && MinClip.y <= 1.0 && MaxClip.x >= -1.0 && MaxClip.y >= -1.0 && MaxViewZ < 0.0;
		const int VisibleObjectId = bIsVisible ? VisibleObjects.size() : -1;
		if (bIsVisible)
		{
			VisibleObjects.emplace_back(Objects[i], vec4(MinClip, MaxClip), vec2(MinDist, MaxDist));
		}
		if (Objects[i].bShadowCaster)
		{
			ShadowCasters.emplace_back(Objects[i], VisibleObjectId);
		}
	}

	// Upload the information for objects required for rendering.
	const int VisibleObjectsCount = VisibleObjects.size();
	const int ShadowCastersCount = ShadowCasters.size();

	VisibleObjectsBuffer.Upload((void*)VisibleObjects.data(), sizeof(ShapeUploadInfo) * VisibleObjectsCount);
	ShadowCastersBuffer.Upload((void*)ShadowCasters.data(), sizeof(ShapeUploadInfo) * ShadowCastersCount);

	VisibleObjectsBuffer.Bind(GL_SHADER_STORAGE_BUFFER, 0);
	ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	ViewInfo.Bind(GL_UNIFORM_BUFFER, 2);

	// Draw all of the everything
	if (VisibleObjectsCount > 0)
	{
#if PROFILING
		glBeginQuery(GL_TIME_ELAPSED, DepthPassTime);
#endif
		glDrawArraysInstanced(GL_TRIANGLES, 0, 6, VisibleObjectsCount);
#if PROFILING
		glEndQuery(GL_TIME_ELAPSED);
#endif
	}
	glPopDebugGroup();

	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Gloom");
	glDepthMask(GL_FALSE);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_CULL_FACE);
	glEnable(GL_BLEND);
	glBlendEquation(GL_FUNC_ADD);
	glBlendFunc(GL_DST_COLOR, GL_ZERO);
	glBindFramebuffer(GL_FRAMEBUFFER, GloomPass);
	ShadowCastersBuffer.Bind(GL_SHADER_STORAGE_BUFFER, 0);
	glBindTextureUnit(1, DepthBuffer);
	glBindTextureUnit(2, ObjectIdBuffer);
	GloomShader.Activate();
	glClearColor(1.0, 1.0, 1.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);

	// Cast Shadows
	if (VisibleObjectsCount > 0)
	{
#if PROFILING
		glBeginQuery(GL_TIME_ELAPSED, GloomPassTime);
#endif
		glDrawArraysInstanced(GL_TRIANGLES, 0, 3, ShadowCastersCount);
#if PROFILING
		glEndQuery(GL_TIME_ELAPSED);
#endif
	}
	glPopDebugGroup();

	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Color");
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_CULL_FACE);
	glDisable(GL_BLEND);
	glBindFramebuffer(GL_FRAMEBUFFER, ColorPass);
	VisibleObjectsBuffer.Bind(GL_SHADER_STORAGE_BUFFER, 0);
	glBindTextureUnit(3, GloomBuffer);
	ColorShader.Activate();
#if ENABLE_RESOLUTION_SCALING
	if (ResolutionScale < 1.0)
	{
		UpdateScreenInfo(false);
		ScreenInfo.Bind(GL_UNIFORM_BUFFER, 1);
	}
#endif //ENABLE_RESOLUTION_SCALING

#if PROFILING
	glBeginQuery(GL_TIME_ELAPSED, ColorPassTime);
#endif
	glDrawArrays(GL_TRIANGLES, 0, 3);
#if PROFILING
	glEndQuery(GL_TIME_ELAPSED);
#endif
	glPopDebugGroup();

#if VINE_MODE
	if (FrameCounter > -1)
	{
		std::vector<char> PixelData;
		const size_t Channels = 4;
		PixelData.resize(size_t(VineModeWidth) * size_t(VineModeHeight) * Channels);
		glNamedFramebufferReadBuffer(ColorPass, GL_COLOR_ATTACHMENT0);
		glReadPixels(0, 0, GLsizei(VineModeWidth), GLsizei(VineModeHeight), GL_RGBA, GL_UNSIGNED_BYTE, PixelData.data());
		FILE* FileHandle;
		FileHandle = fopen("frames/raw_data", "ab");
		fwrite(PixelData.data(), sizeof(char), PixelData.size(), FileHandle);
		fclose(FileHandle);
	}
#endif // VINE_MODE

#if PROFILING
	glQueryCounter(FrameEndTime, GL_TIMESTAMP);
	{
		const int StatSamples = 100;
		static double DepthPassTimeSamplesNS[StatSamples] = { 0.0 };
		static double GloomPassTimeSamplesNS[StatSamples] = { 0.0 };
		static double ColorPassTimeSamplesNS[StatSamples] = { 0.0 };

		{
			const int Sample = FrameCounter % StatSamples;
			DepthPassTimeSamplesNS[Sample] = double(GetQueryValue(DepthPassTime, GL_QUERY_RESULT));
			GloomPassTimeSamplesNS[Sample] = double(GetQueryValue(GloomPassTime, GL_QUERY_RESULT));
			ColorPassTimeSamplesNS[Sample] = double(GetQueryValue(ColorPassTime, GL_QUERY_RESULT));
		}

		const double ValidSamples = min(FrameCounter + 1, StatSamples);
		const double InvValidSamples = 1.0 / ValidSamples;
		double AverageDepthPassTimeNs = 0.0;
		double AverageGloomPassTimeNs = 0.0;
		double AverageColorPassTimeNs = 0.0;
		for (int Sample = 0; Sample < ValidSamples; ++Sample)
		{
			AverageDepthPassTimeNs += DepthPassTimeSamplesNS[Sample] * InvValidSamples;
			AverageGloomPassTimeNs += GloomPassTimeSamplesNS[Sample] * InvValidSamples;
			AverageColorPassTimeNs += ColorPassTimeSamplesNS[Sample] * InvValidSamples;
		}
		const double AverageTotalDrawTimeNs = AverageDepthPassTimeNs + AverageGloomPassTimeNs + AverageColorPassTimeNs;
		Log::GetStream() \
			<< "Objects Drawn: " << VisibleObjectsCount << " / " << Objects.size() << "\n\n"
			<< "Average GPU Times:\n"
			<< " - Depth: " << (AverageDepthPassTimeNs * 1e-6) << " ms\n"
			<< " - Gloom: " << (AverageGloomPassTimeNs * 1e-6) << " ms\n"
			<< " - Color: " << (AverageColorPassTimeNs * 1e-6) << " ms\n"
			<< " - Total: " << (AverageTotalDrawTimeNs * 1e-6) << " ms\n"
			<< "\n";
	}
#endif
}
