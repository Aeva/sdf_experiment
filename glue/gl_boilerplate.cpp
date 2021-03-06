#include <iostream>
#include <fstream>
#include <set>
#include "gl_boilerplate.h"


static int ScreenWidth = 512;
static int ScreenHeight = 512;
static float DPIScaleX = 1.0;
static float DPIScaleY = 1.0;


void SetScreenSize(int Width, int Height)
{
	ScreenWidth = Width;
	ScreenHeight = Height;
}


void GetScreenSize(int* Width, int* Height)
{
	*Width = ScreenWidth;
	*Height = ScreenHeight;
}


void GetScreenSize(float* Width, float* Height)
{
	*Width = (float)ScreenWidth;
	*Height = (float)ScreenHeight;
}


void SetDPIScale(float ScaleX, float ScaleY)
{
	DPIScaleX = ScaleX;
	DPIScaleY = ScaleY;
}


void GetDPIScale(float* ScaleX, float* ScaleY)
{
	*ScaleX = DPIScaleX;
	*ScaleY = DPIScaleY;
}


std::string GetInfoLog(GLuint ObjectId)
{
	GLint LogLength;
	glGetProgramiv(ObjectId, GL_INFO_LOG_LENGTH, &LogLength);
	if (LogLength)
	{
		std::string InfoLog(LogLength, 0);
		glGetProgramInfoLog(ObjectId, LogLength, NULL, (char*)InfoLog.data());
		return InfoLog;
	}
	else
	{
		return std::string();
	}
}


bool IsPrepender(std::string Line, std::string& NextPath)
{
	const std::string Prefix = "prepend: ";
	if (Line.size() >= Prefix.size())
	{
		const std::string Test = Line.substr(0, Prefix.size());
		if (Test == Prefix)
		{
			NextPath = Line.substr(Prefix.size(), Line.size() - Prefix.size());
			return true;
		}
	}
	return false;
}


bool IsPerforation(std::string Line)
{
	// Matches ^----*$
	if (Line.size() < 3)
	{
		return false;
	}
	for (int i=0; i<Line.size(); i++)
	{
		if (Line[i] != '-' && Line[i] != '\r')
		{
			return false;
		}
	}
	return true;
}


StatusCode FillSources(std::vector<std::string>& BreadCrumbs, std::vector<std::string>& Index, std::vector<std::string>& Sources, std::string Path)
{
	for (const auto& Visited : BreadCrumbs)
	{
		if (Path == Visited)
		{
			return StatusCode::PASS;
		}
	}
	BreadCrumbs.push_back(Path);

	std::ifstream File(Path);
	if (!File.is_open())
	{
		std::cout << "Error: cannot open file \"" << Path << "\"\n";
		return StatusCode::FAIL;
	}
	std::string Line;
	std::string Source;

	// Scan for prepends
	bool bFoundPrepend = false;
	bool bFoundTear = false;
	int TearLine = -1;
	for (int LineNumber = 0; getline(File, Line); ++LineNumber)
	{
		std::string Detour;
		if (IsPerforation(Line))
		{
			bFoundTear = true;
			TearLine = LineNumber;
			break;
		}
		else if (IsPrepender(Line, Detour))
		{
			bFoundPrepend = true;
			RETURN_ON_FAIL(FillSources(BreadCrumbs, Index, Sources, Detour));
			continue;
		}
		else
		{
			break;
		}
	}

	if (bFoundPrepend && !bFoundTear)
	{
		std::cout << "Error in file \"" << Path << "\":\n";
		std::cout << "  Cannot use prepend statements without a perforated line.\n";
		return StatusCode::FAIL;
	}

	Index.push_back(Path);
	File.seekg(0);
	if (bFoundTear)
	{
		for (int LineNumber = 0; LineNumber <= TearLine; ++LineNumber)
		{
			getline(File, Line);
		}
		Source = "#line ";
		Source += std::to_string(TearLine + 1);
		Source += " ";
		Source += std::to_string(Index.size() - 1);
		Source += "\n";
	}
	else
	{
		Source = "#line 0 ";
		Source += std::to_string(Index.size() - 1);
		Source += "\n";
	}

	while (getline(File, Line))
	{
		Source += Line + '\n';
	}

	File.close();
	Sources.push_back(Source);
	return StatusCode::PASS;
}


const std::string GetShaderExtensions(GLenum ShaderType)
{
	std::string Version = "#version 420\n";

#if GL_NV_mesh_shader
	if (GLAD_GL_NV_mesh_shader)
	{
		Version = "#version 450\n";
	}
#endif

	static const std::string VertexExtensions = \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shader_storage_buffer_object : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n";

	static const std::string FragmentExtensions = \
		"#extension GL_ARB_shader_storage_buffer_object : require\n" \
		"#extension GL_ARB_shader_image_load_store : require\n" \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n" \
		"#extension GL_ARB_fragment_coord_conventions : require\n";

	static const std::string ComputeExtensions = \
		"#extension GL_ARB_compute_shader : require\n" \
	   	"#extension GL_ARB_shader_storage_buffer_object : require\n" \
	   	"#extension GL_ARB_shader_image_load_store : require\n" \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n";

#if GL_NV_mesh_shader
	static const std::string MeshExtensions = \
		"#extension GL_NV_mesh_shader : require\n";
#endif

	if (ShaderType == GL_VERTEX_SHADER)
	{
		return Version + VertexExtensions;
	}
	else if (ShaderType == GL_FRAGMENT_SHADER)
	{
		return Version + FragmentExtensions;
	}
	else if (ShaderType == GL_MESH_SHADER_NV)
	{
		return Version + MeshExtensions;
	}
	else if (ShaderType == GL_TASK_SHADER_NV)
	{
		return Version + MeshExtensions;
	}
	else
	{
		return Version + ComputeExtensions;
	}
}


StatusCode CompileShader(GLenum ShaderType, std::string Path, GLuint& ProgramID)
{
	const std::string Extensions = GetShaderExtensions(ShaderType);

	std::vector<std::string> Sources;
	std::vector<std::string> BreadCrumbs;
	std::vector<std::string> Index;
	Sources.push_back(Extensions);
	Index.push_back("(generated block)");
	RETURN_ON_FAIL(FillSources(BreadCrumbs, Index, Sources, Path));

	const int Count = Sources.size();
	std::vector<const char*> Strings;
	Strings.reserve(Count);
	for (int i=0; i<Count; ++i)
	{
		Strings.push_back(Sources[i].c_str());
	}
	ProgramID = glCreateShaderProgramv(ShaderType, Count, Strings.data());
	{
		const size_t Start = Path.find_last_of("/") + 1;
		const size_t End = Path.find_last_of(".");
		const size_t Span = End > Start ? End - Start : -1;
		std::string ProgramName = Path.substr(Start, Span);
		glObjectLabel(GL_PROGRAM, ProgramID, -1, ProgramName.c_str());
	}

	GLint LinkStatus;
	glGetProgramiv(ProgramID, GL_LINK_STATUS, &LinkStatus);
	if (!LinkStatus)
	{
		std::string Error = GetInfoLog(ProgramID);
		if (!Error.empty())
		{
			std::cout << "Generated part:\n" << Sources[0] << "\n\n";
			std::cout << "Shader string paths:\n";
			for (int i = 0; i < Index.size(); ++i)
			{
				std::cout << i << " -> " << Index[i] << "\n";
			}
			std::cout << "\n" << Error << '\n';
			return StatusCode::FAIL;
		}
	}
	return StatusCode::PASS;
}


GLuint ShaderModeBit(GLenum ShaderMode)
{
	if (ShaderMode == GL_VERTEX_SHADER) return GL_VERTEX_SHADER_BIT;
	else if (ShaderMode == GL_TESS_CONTROL_SHADER) return GL_TESS_CONTROL_SHADER_BIT;
	else if (ShaderMode == GL_TESS_EVALUATION_SHADER) return GL_TESS_EVALUATION_SHADER_BIT;
	else if (ShaderMode == GL_GEOMETRY_SHADER) return GL_GEOMETRY_SHADER_BIT;
	else if (ShaderMode == GL_FRAGMENT_SHADER) return GL_FRAGMENT_SHADER_BIT;
	else if (ShaderMode == GL_COMPUTE_SHADER) return GL_COMPUTE_SHADER_BIT;
	else if (ShaderMode == GL_MESH_SHADER_NV) return GL_MESH_SHADER_BIT_NV;
	else if (ShaderMode == GL_TASK_SHADER_NV) return GL_TASK_SHADER_BIT_NV;
	else return 0;
}


StatusCode ShaderPipeline::Setup(std::map<GLenum, std::string> Shaders, const char* PipelineName)
{
	glCreateProgramPipelines(1, &PipelineID);
	glObjectLabel(GL_PROGRAM_PIPELINE, PipelineID, -1, PipelineName);
	for (const auto& Shader : Shaders)
	{
		RETURN_ON_FAIL(CompileShader(Shader.first, Shader.second, Stages[Shader.first]));
		glUseProgramStages(PipelineID, ShaderModeBit(Shader.first), Stages[Shader.first]);
	}
	glValidateProgramPipeline(PipelineID);
	GLint ValidationStatus;
	glGetProgramPipelineiv(PipelineID, GL_VALIDATE_STATUS, &ValidationStatus);
	if (!ValidationStatus)
	{
		std::string Error = GetInfoLog(PipelineID);
		std::cout << Error << "\n";
		return StatusCode::FAIL;
	}
	return StatusCode::PASS;
}


void ShaderPipeline::Activate()
{
	glBindProgramPipeline(PipelineID);
}


Buffer::Buffer(const char* InDebugName)
	: BufferID(0)
	, LastSize(0)
	, DebugName(InDebugName)
{
}


Buffer::~Buffer()
{
	Release();
}


inline void Buffer::Release()
{
	if (BufferID != 0)
	{
		glDeleteBuffers(1, &BufferID);
		BufferID = 0;
	}
}


void Buffer::Upload(void* Data, size_t Bytes)
{
	if (Bytes != LastSize)
	{
		Release();
	}
	if (BufferID == 0)
	{
		glCreateBuffers(1, &BufferID);
		if (DebugName != nullptr)
		{
			glObjectLabel(GL_BUFFER, BufferID, -1, DebugName);
		}
		glNamedBufferStorage(BufferID, Bytes, Data, GL_DYNAMIC_STORAGE_BIT);
		LastSize = Bytes;
	}
	else
	{
		glNamedBufferSubData(BufferID, 0, Bytes, Data);
	}
}


void Buffer::Bind(GLenum Target, GLuint BindingIndex)
{
	glBindBufferBase(Target, BindingIndex, BufferID);
}
