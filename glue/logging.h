#include<sstream>


namespace Log
{
	std::stringstream& GetStream();
	void Clear();
	void Flush();
}
