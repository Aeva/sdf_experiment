--------------------------------------------------------------------------------

// ---------
// Misc Math
// ---------

#define IS_SOLID(val) (val < AlmostZero)
#define RADIANS(Degrees) (Degrees * 0.017453292519943295)


vec3 Transform3(mat4 Matrix, vec3 Point)
{
	vec4 Fnord = Matrix * vec4(Point, 1.0);
    return Fnord.xyz / Fnord.w;
}
    
    
vec2 Rotate2D(vec2 Point, float Radians)
{
	vec2 SinCos = vec2(sin(Radians), cos(Radians));
	return vec2(
		SinCos.y * Point.x + SinCos.x * Point.y,
		SinCos.y * Point.y - SinCos.x * Point.x);
}


vec3 RotateX(vec3 Point, float Radians)
{
	vec2 Rotated = Rotate2D(Point.yz, Radians);
	return vec3(Point.x, Rotated.xy);
}


vec3 RotateY(vec3 Point, float Radians)
{
	vec2 Rotated = Rotate2D(Point.xz, Radians);
	return vec3(Rotated.x, Point.y, Rotated.y);
}


vec3 RotateZ(vec3 Point, float Radians)
{
	vec2 Rotated = Rotate2D(Point.xy, Radians);
	return vec3(Rotated.xy, Point.z);
}
