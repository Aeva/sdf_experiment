#include "logging.h"
#include<iostream>


std::stringstream LogStream;


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
	std::cout << LogStream.str();
	Log::Clear();
}
