#include "errors.h"


static bool HCF = false;


void SetHaltAndCatchFire()
{ 
	HCF = true;
}


bool GetHaltAndCatchFire()
{
	return HCF;
}
