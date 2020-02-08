#include "logging.h"
#include "../shaders/defs.glsl"
#if ENABLE_TEXT_OVERLAY
#include "gl_boilerplate.h"
#include "lodepng.h"
#endif
#include <iostream>
#include <string>
#include <vector>


std::stringstream LogStream;

#if ENABLE_TEXT_OVERLAY
ShaderPipeline TextShader;
GLuint TextAtlasTextureID;

const int AtlasMin = 32;
const int AtlasMax = 127;
const int GlyphWidth = 9;
const int GlyphHeight = 20;
const int GlyphCount = AtlasMax - AtlasMin;

const int AtlasWidth = GlyphWidth * GlyphCount;
const int AtlasHeight = GlyphHeight;


struct SlugInfo
{
	GLuint TextureID;
	Buffer TextParams;
	int Line;

	SlugInfo(std::string Text, int InLine)
	{
		Line = InLine;
		glCreateTextures(GL_TEXTURE_2D, 1, &TextureID);
		glTextureStorage2D(TextureID, 1, GL_R8I, Text.size(), 1);
		glTextureParameteri(TextureID, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(TextureID, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTextureSubImage2D(TextureID, 0, 0, 0, Text.size(), 1, GL_RED_INTEGER, GL_BYTE, (const void*)Text.data());

		GLfloat BufferData[4] = {
			float(Line),
			float(Text.size()),
			0.0,
			0.0
		};
		TextParams.Upload((void*)&BufferData, sizeof(BufferData));
	}

	~SlugInfo()
	{
		glDeleteTextures(1, &TextureID);
	}
};


std::vector<SlugInfo> Slugs;


StatusCode TextRendering::Setup()
{
	RETURN_ON_FAIL(TextShader.Setup(
		{ {GL_VERTEX_SHADER, "shaders/text.vs.glsl"},
		 {GL_FRAGMENT_SHADER, "shaders/text.fs.glsl"} },
		"Text"));

	std::vector<unsigned char> ImageData;
	unsigned ImageWidth;
	unsigned ImageHeight;
	unsigned Error = lodepng::decode(ImageData, ImageWidth, ImageHeight, "ascii.png");
	if (Error)
	{
		std::cout \
			<< "Failed to read ascii.png!\n"
			<< " - Reason: PNG decode error:\n"
			<< " - [" << Error << "] " << lodepng_error_text(Error) << "\n";
		return StatusCode::FAIL;
	}
	if (ImageWidth != AtlasWidth || ImageHeight != AtlasHeight)
	{
		std::cout \
			<< "Failed to read ascii.png!\n"
			<< " - Reason: Image not expected size.\n";
		return StatusCode::FAIL;
	}

	glCreateTextures(GL_TEXTURE_2D, 1, &TextAtlasTextureID);
	glTextureStorage2D(TextAtlasTextureID, 1, GL_RGBA8, AtlasWidth, AtlasHeight);
	glTextureParameteri(TextAtlasTextureID, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTextureParameteri(TextAtlasTextureID, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTextureSubImage2D(TextAtlasTextureID, 0, 0, 0, ImageWidth, ImageHeight, GL_RGBA, GL_UNSIGNED_BYTE, ImageData.data());

	return StatusCode::PASS;
}


void TextRendering::Render(const int FrameCounter)
{
	glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "Text Overlay");
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glEnable(GL_BLEND);
	glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
	glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO);
	glBindTextureUnit(0, TextAtlasTextureID);
	TextShader.Activate();
	for (SlugInfo& Slug : Slugs)
	{
		glBindTextureUnit(3, Slug.TextureID);
		Slug.TextParams.Bind(GL_UNIFORM_BUFFER, 2);
		glDrawArrays(GL_TRIANGLES, 0, 6);
	}
	glDisable(GL_BLEND);
	glPopDebugGroup();
}


void MakeSlugs(std::string LogString)
{
	Slugs.clear();
	size_t Cursor = 0;
	int Line = 0;
	while (Cursor < LogString.size())
	{
		size_t Slice = LogString.find('\n', Cursor);
		if (Slice == -1)
		{
			Slice = LogString.size() - 1;
		}

		size_t Count = Slice - Cursor;
		if (Count > 0)
		{
			Slugs.emplace_back(LogString.substr(Cursor, Count), Line);
		}
		Cursor = Slice + 1;
		++Line;
	}
}
#else
StatusCode TextRendering::Setup()
{
	return StatusCode::PASS;
}


void TextRendering::Render(const int FrameCounter)
{
}
#endif //ENABLE_TEXT_OVERLAY


std::stringstream& Log::GetStream()
{
	return LogStream;
}


void Log::Clear()
{
	LogStream.str("");
}


void Log::Flush()
{
#if ENABLE_TEXT_OVERLAY
	MakeSlugs(LogStream.str());
	Log::Clear();
#else
	std::cout << LogStream.str();
	LogStream.str("\n\n");
#endif //ENABLE_TEXT_OVERLAY
}
