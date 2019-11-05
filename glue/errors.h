#pragma once
#if DEBUG_BUILD
#include <iostream>
#endif


void SetHaltAndCatchFire();
bool GetHaltAndCatchFire();


enum class StatusCode
{
	PASS,
	FAIL
};


#define RETURN_ON_FAIL(Expr) { StatusCode Result = Expr; if (Result == StatusCode::FAIL) return Result; }
#if DEBUG_BUILD
#define ASSERT(Expr) if (!Expr) { std::cout << "assertion failed in " << __FILE __ << ":" << __LINE__ << ", in function \"" << __func__ << "\"\n"; SetHaltAndCatchFire(); }
#else
#define ASSERT(Expr)
#endif