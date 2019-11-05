#pragma once
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <vector>
#include <string>
#include <map>
#include "errors.h"


void SetScreenSize(int Width, int Height);


void GetScreenSize(int* Width, int* Height);


void GetScreenSize(float* Width, float* Height);


void SetDPIScale(float ScaleX, float ScaleY);


void GetDPIScale(float* ScaleX, float* ScaleY);


struct ShaderPipeline
{
	GLuint PipelineID = 0;
	std::map<GLenum, GLuint> Stages;
	std::vector<struct BindingPoint*> BindingPoints;

	StatusCode Setup(std::map<GLenum, std::string> Shaders);
	void Activate();
};


struct Buffer
{
	GLuint BufferID = 0;
	void Initialize(size_t Bytes);
	void Upload(void* Data, size_t Bytes);
	void Bind(GLenum Target, GLuint BindingIndex);
};


struct BufferPool
{
	std::vector<Buffer> Data;
	int Tracker;
	BufferPool();
	void Reset();
	Buffer& Next();
	Buffer* begin();
	Buffer* end();
};
