
#include <iostream>
#include "errors.h"
#include "gl_boilerplate.h"
#include "../sdf_experiment.h"
#if PROFILING
#include "logging.h"
#endif //PROFILING

#if RENDERDOC_CAPTURE_AND_QUIT
#include "../renderdoc.h"
#include <dlfcn.h>
RENDERDOC_API_1_1_2 *rdoc_api = NULL;
#endif

GLFWwindow* Window;


void ErrorCallback(int Error, const char* Description)
{
	std::cout << "Error: " << Description << '\n';
	SetHaltAndCatchFire();
}


void DebugCallback(
	GLenum Source, 
	GLenum Type, 
	GLuint Id, 
	GLenum Severity, 
	GLsizei MessageLength, 
	const GLchar *ErrorMessage, 
	const void *UserParam)
{
    std::cout << ErrorMessage << "\n";
}


static bool WindowIsDirty = true;


void WindowSizeCallback(GLFWwindow* Window, int Width, int Height)
{
	SetScreenSize(Width, Height);
	WindowIsDirty = true;
}


void WindowContentScaleCallback(GLFWwindow* Window, float ScaleX, float ScaleY)
{
	SetDPIScale(ScaleX, ScaleY);
	WindowIsDirty = true;
}


StatusCode SetupGLFW()
{
	glfwSetErrorCallback(ErrorCallback);
	if (!glfwInit())
	{
		std::cout << "glfw init failed\n";
		return StatusCode::FAIL;
	}

	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#if DEBUG_BUILD
	glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
#endif
	glfwWindowHint(GLFW_SCALE_TO_MONITOR, GL_TRUE); // highdpi

	int ScreenWidth = 512;
	int ScreenHeight = 512;

	Window = glfwCreateWindow(ScreenWidth, ScreenHeight, "meep", NULL, NULL);
	if (!Window)
	{
		std::cout << "failed to create glfw window\n";
		glfwTerminate();
		return StatusCode::FAIL;
	}
	glfwMakeContextCurrent(Window);

	int WindowWidth;
	int WindowHeight;
	glfwGetWindowSize(Window, &WindowWidth, &WindowHeight);
	SetScreenSize(WindowWidth, WindowHeight);
	glfwSetWindowSizeCallback(Window, WindowSizeCallback);

	float DPIScaleX;
	float DPIScaleY;
	glfwGetWindowContentScale(Window, &DPIScaleX, &DPIScaleY);
	SetDPIScale(DPIScaleX, DPIScaleY);
	glfwSetWindowContentScaleCallback(Window, WindowContentScaleCallback);

	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		std::cout << "Failed to initialize OpenGL context" << std::endl;
		return StatusCode::FAIL;
	}
	else
	{
		std::cout << "Found OpenGL version " << GLVersion.major << "." << GLVersion.minor << "\n";
	}

#if DEBUG_BUILD
	if (GLAD_GL_ARB_debug_output)
	{
		GLint ContextFlags;
		glGetIntegerv(GL_CONTEXT_FLAGS, &ContextFlags);
		if (ContextFlags & GL_CONTEXT_FLAG_DEBUG_BIT)
		{
			glEnable(GL_DEBUG_OUTPUT);
			glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
			glDebugMessageCallbackARB(&DebugCallback, nullptr);
			glDebugMessageControlARB(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nullptr, GL_TRUE);
		}
		else
		{
			std::cout << "Debug context not available!\n";
		}
	}
	else
	{
		std::cout << "Debug output extension not available!\n";
	}
#endif

	std::cout << glGetString(GL_VERSION) << '\n';

	GLint MaxVertexSSBOs;
	glGetIntegerv(GL_MAX_VERTEX_SHADER_STORAGE_BLOCKS, &MaxVertexSSBOs);
	GLint MaxFragmentSSBOs;
	glGetIntegerv(GL_MAX_FRAGMENT_SHADER_STORAGE_BLOCKS, &MaxFragmentSSBOs);
	GLint MaxComputeSSBOs;
	glGetIntegerv(GL_MAX_COMPUTE_SHADER_STORAGE_BLOCKS, &MaxComputeSSBOs);
	std::cout << "Max Vertex SSBO Blocks: " << MaxVertexSSBOs << '\n'
    	<< "Max Fragment SSBO Blocks: " << MaxFragmentSSBOs << '\n'
		<< "Max Compute SSBO Blocks: " << MaxComputeSSBOs << '\n';

#if RENDERDOC_CAPTURE_AND_QUIT
	if(void *mod = dlopen("librenderdoc.so", RTLD_NOW | RTLD_NOLOAD))
	{
    	pRENDERDOC_GetAPI RENDERDOC_GetAPI = (pRENDERDOC_GetAPI)dlsym(mod, "RENDERDOC_GetAPI");
    	int RenderdocStatus = RENDERDOC_GetAPI(eRENDERDOC_API_Version_1_1_2, (void **)&rdoc_api);
    	if (RenderdocStatus != 1)
    	{
    		std::cout << "Could not initialize RenderDoc.\n";
    		return StatusCode::FAIL;
    	}
	}
#endif

	return StatusCode::PASS;
}


StatusCode DemoSetup ()
{
	glUseProgram(0);
	RETURN_ON_FAIL(SDFExperiment::Setup(Window));
	return StatusCode::PASS;
}

void DrawFrame()
{
	static int FrameCounter = -1;
	FrameCounter += 1;
#if PROFILING
	const int StatSamples = 50;
	static double FPS[StatSamples] = { 0.0 };
	static double RenderTimeMS[StatSamples] = { 0.0 };
	static double PresentTimeMS[StatSamples] = { 0.0 };
	{
		static double LastTime = 0.0;
		const double Now = glfwGetTime();
		FPS[FrameCounter % StatSamples] = 1.0 / (Now - LastTime);
		LastTime = Now;
	}
	Log::GetStream() << "\n\n";
#endif

	if (WindowIsDirty)
	{
		SDFExperiment::WindowIsDirty();
		WindowIsDirty = false;
	}

#if PROFILING
	{
		const double Start = glfwGetTime();
#endif
		SDFExperiment::Render(FrameCounter);
#if PROFILING
		RenderTimeMS[FrameCounter % StatSamples] = (glfwGetTime() - Start) * 1000.0;
	}
	{
		const double Start = glfwGetTime();
#endif
		glfwSwapBuffers(Window);
		glFinish();
#if PROFILING
		PresentTimeMS[FrameCounter % StatSamples] = (glfwGetTime() - Start) * 1000.0;
	}

	double AverageFPS = 0.0;
	double AverageRenderTimeMS = 0.0;
	double AveragePresentTimeMS = 0.0;
	{
		const int SampleCount = (FrameCounter % StatSamples) + 1;
		const double InvSampleCount = 1.0 / double(SampleCount);
		for (int Sample = 0; Sample < SampleCount; ++Sample)
		{
			AverageFPS += FPS[Sample] * InvSampleCount;
			AverageRenderTimeMS += RenderTimeMS[Sample] * InvSampleCount;
			AveragePresentTimeMS += PresentTimeMS[Sample] * InvSampleCount;
		}
	}

	Log::GetStream() \
		<< "Average CPU Times:\n"
		<< " - Render: " << AverageRenderTimeMS << " ms\n"
		<< " - Present: " << AveragePresentTimeMS << " ms\n"
		<< " - FPS: " << AverageFPS << "\n";
	Log::Flush();
#endif
	glfwPollEvents();
}


#define QUIT_ON_FAIL(Expr) if (Expr == StatusCode::FAIL) return 1;


int main()
{
	QUIT_ON_FAIL(SetupGLFW());

#if RENDERDOC_CAPTURE_AND_QUIT
	if (rdoc_api != nullptr)
	{
		rdoc_api->StartFrameCapture(NULL, NULL);
#endif
		QUIT_ON_FAIL(DemoSetup());

#if !RENDERDOC_CAPTURE_AND_QUIT
		while(!glfwWindowShouldClose(Window) && !GetHaltAndCatchFire())
#endif
		{
			DrawFrame();
		}
#if RENDERDOC_CAPTURE_AND_QUIT
		rdoc_api->EndFrameCapture(NULL, NULL);
	}
#endif

	glfwDestroyWindow(Window);
	glfwTerminate();
	return 0;
}
