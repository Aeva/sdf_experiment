#include "errors.h"
#include<sstream>


namespace TextRendering
{
	StatusCode Setup();
	void Render(const int FrameCounter);
}


namespace Log
{
	std::stringstream& GetStream();
	void Clear();
	void Flush();
}
