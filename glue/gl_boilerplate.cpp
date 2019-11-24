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


StatusCode FillSources(std::vector<std::string>& BreadCrumbs, std::vector<std::string>& Sources, std::string Path)
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
	bool bFoundTear = false;
	int OriginalLine = -1;
	while (getline(File, Line))
	{
		++OriginalLine;
		if (!bFoundTear)
		{
			std::string Detour;
			if (IsPerforation(Line))
			{
				bFoundTear = true;
				Source.erase();
				Source = "#line ";
				Source += std::to_string(OriginalLine + 1);
				Source += "\n";
				continue;
			}
			else if (IsPrepender(Line, Detour))
			{
				RETURN_ON_FAIL(FillSources(BreadCrumbs, Sources, Detour));
				continue;
			}
		}
		Source += Line + '\n';
	}
	File.close();
	Sources.push_back(Source);
	return StatusCode::PASS;
}


const std::string GetShaderExtensions(GLenum ShaderType)
{
	static const std::string VertexExtensions = \
		"#version 420\n" \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shader_storage_buffer_object : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n";

	static const std::string FragmentExtensions = \
		"#version 420\n" \
		"#extension GL_ARB_shader_storage_buffer_object : require\n" \
		"#extension GL_ARB_shader_image_load_store : require\n" \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n" \
		"#extension GL_ARB_fragment_coord_conventions : require\n";

	static const std::string ComputeExtensions = \
		"#version 420\n" \
		"#extension GL_ARB_compute_shader : require\n" \
	   	"#extension GL_ARB_shader_storage_buffer_object : require\n" \
	   	"#extension GL_ARB_shader_image_load_store : require\n" \
		"#extension GL_ARB_gpu_shader5 : require\n" \
		"#extension GL_ARB_shading_language_420pack : require\n";

	if (ShaderType == GL_VERTEX_SHADER)
	{
		return VertexExtensions;
	}
	else if (ShaderType == GL_FRAGMENT_SHADER)
	{
		return FragmentExtensions;
	}
	else
	{
		return ComputeExtensions;
	}
}


StatusCode CompileShader(GLenum ShaderType, std::string Path, GLuint& ProgramID)
{
	const std::string Extensions = GetShaderExtensions(ShaderType);

	std::vector<std::string> Sources;
	std::vector<std::string> BreadCrumbs;
	Sources.push_back(Extensions);
	BreadCrumbs.push_back("(generated)");
	RETURN_ON_FAIL(FillSources(BreadCrumbs, Sources, Path));

	const int Count = Sources.size();
	std::vector<const char*> Strings;
	Strings.reserve(Count);
	for (int i=0; i<Count; ++i)
	{
		Strings.push_back(Sources[i].c_str());
	}
	ProgramID = glCreateShaderProgramv(ShaderType, Count, Strings.data());
	GLint LinkStatus;
	glGetProgramiv(ProgramID, GL_LINK_STATUS, &LinkStatus);
	if (!LinkStatus)
	{
		std::string Error = GetInfoLog(ProgramID);
		if (!Error.empty())
		{
			std::cout << "Generated part:\n" << Sources[0] << "\n\n";
			std::cout << "Shader string paths:\n";
			for (int i = 0; i < BreadCrumbs.size(); ++i)
			{
				std::cout << i << " -> " << BreadCrumbs[i] << "\n";
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
	else return 0;
}


StatusCode ShaderPipeline::Setup(std::map<GLenum, std::string> Shaders)
{
	glGenProgramPipelines(1, &PipelineID);
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


void Buffer::Initialize(size_t Bytes)
{
	if (BufferID == 0)
	{
		glCreateBuffers(1, &BufferID);
		glNamedBufferStorage(BufferID, Bytes, nullptr, GL_DYNAMIC_STORAGE_BIT);
	}
}


void Buffer::Upload(void* Data, size_t Bytes)
{
	if (BufferID == 0)
	{
		Initialize(Bytes);
	}
	glNamedBufferSubData(BufferID, 0, Bytes, Data);
}


void Buffer::Bind(GLenum Target, GLuint BindingIndex)
{
	glBindBufferBase(Target, BindingIndex, BufferID);
}


BufferPool::BufferPool()
{
	Data.emplace_back();
}


void BufferPool::Reset()
{
	Tracker = 0;
}


Buffer& BufferPool::Next()
{
	if (Tracker == Data.size()-1)
	{
		Data.emplace_back();
	}
	return Data[Tracker++];
}


Buffer* BufferPool::begin()
{
	return Data.size() > 0 ? &Data[0] : nullptr;
}


Buffer* BufferPool::end()
{
	return Data.size() > 0 ? &Data[Tracker] : nullptr;
}
