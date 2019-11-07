prepend: shaders/screen.glsl
--------------------------------------------------------------------------------

layout(std140, binding = 2)
uniform ViewInfoBlock
{
	mat4 WorldToView;
	mat4 ViewToWorld;
	mat4 ViewToClip;
	mat4 ClipToView;
};


layout(std140, binding = 3)
uniform CameraInfoBlock
{
	vec4 CameraOrigin;
};


layout(origin_upper_left) in vec4 gl_FragCoord;


const vec3 UpVector = vec3(0.0, 0.0, 1.0);
const int MaxIterations = 500;
const float AlmostZero = 0.001;
const float MinStep = 0.001;


struct ColorSDF
{
    float Distance;
    int PaintFn;
    vec3 Local;
    vec3 Extent;
};


// ---------
// Misc Math
// ---------

#define IS_SOLID(val) val < AlmostZero
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


// ------------
// Ray Marching
// ------------

vec3 GetRayDir()
{
	const vec2 NDC = gl_FragCoord.xy * ScreenSize.zw * 2.0 - 1.0;
	vec4 View = ClipToView * vec4(NDC.xy, -1.0, 1.0);
	View = vec4(normalize(vec3(View.x, View.y, View.z) / View.w), 1.0);
	vec4 World = ViewToWorld * View;
	return normalize(vec3(World.xyz / World.w) - CameraOrigin.xyz);
}


ColorSDF SceneSDF(vec3 Position);


void RayTrace(out vec3 Position, out ColorSDF Scene)
{
	const vec3 RayDir = GetRayDir();
	const float Fudge = 0.2;
	Position = RayDir * max(DepthRange.x - Fudge, 0.0) + CameraOrigin.xyz;

	for (int Step = 0; Step <= MaxIterations; ++Step)
    {
		Scene = SceneSDF(Position);
        if (IS_SOLID(Scene.Distance))
        {
            return;
        }
     	else
        {
		    Position += RayDir * min(max(Scene.Distance, MinStep), 10.0);
			if (distance(Position, CameraOrigin.xyz) > DepthRange.y)
			{
				break;
			}
        }
    }
	Scene.PaintFn = -1;
}


// ------------------------------------------------------------------
// 1D bezier curve math via Shane Celis:
// https://twitter.com/shanecelis/status/1187018771543793664
// ------------------------------------------------------------------

float QuadraticBezierTransform(float Point, vec2 Range, vec3 Controls)
{
    // This is a 1D spatial transform.  Point is whatever scalar value.
    // Range is the limits such that Range.x < Point < Range.y.
    // Controls are the control points of the 1D curve.
    // Point == Range.x means alpha is 0, etc.
    float Low = min(Range.x, Range.y);
    float High = max(Range.x, Range.y);
    float Blend = (Point - Low) / (High - Low);
    float InvBlend = 1.0 - Blend;
    vec3 Influences = vec3(InvBlend * InvBlend, 2.0 * InvBlend * Blend, Blend * Blend);
    return dot(Influences, Controls);
}


// ------------------------------------------------------------------
// The sd* op* signed distance field math functions below are from:
// http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
// ------------------------------------------------------------------

float sdSphere(vec3 p, float s)
{
    return length(p)-s;
}


float sdBox(vec3 p, vec3 b)
{
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}


float sdCylinder(vec3 p, vec3 c)
{
    return length(p.xz-c.xy)-c.z;
}


float opUnion(float d1, float d2)
{
    return min(d1,d2);
}


float opSubtraction(float d1, float d2)
{
    return max(d1,-d2);
}


float opIntersection(float d1, float d2)
{
    return max(d1,d2);
}


// ---------------
// Shape Operators
// ---------------

ColorSDF Union(ColorSDF LHS, ColorSDF RHS)
{
    float Combined = opUnion(LHS.Distance, RHS.Distance);
    if (distance(Combined, LHS.Distance) <= distance(Combined, RHS.Distance))
    {
        LHS.Distance = Combined;
        return LHS;
    }
    else
    {
        RHS.Distance = Combined;
        return RHS;
    }
}


ColorSDF Intersection(ColorSDF LHS, ColorSDF RHS)
{
    float Combined = opIntersection(LHS.Distance, RHS.Distance);
    if (distance(Combined, LHS.Distance) <= distance(Combined, RHS.Distance))
    {
        LHS.Distance = Combined;
        return LHS;
    }
    else
    {
        RHS.Distance = Combined;
        return RHS;
    }
}


ColorSDF Replace(ColorSDF LHS, ColorSDF RHS)
{
    float Distance = opIntersection(LHS.Distance, RHS.Distance);
    if (IS_SOLID(Distance))
    {
        RHS.Distance = Distance;
        return RHS;
    }
    return LHS;
}


ColorSDF Cut(ColorSDF LHS, ColorSDF RHS)
{
    LHS.Distance = opSubtraction(LHS.Distance, RHS.Distance);
    return LHS;
}


ColorSDF CutAndPaint(ColorSDF LHS, ColorSDF RHS)
{
    float Distance = opSubtraction(LHS.Distance, RHS.Distance);
    if (IS_SOLID(RHS.Distance))
    {
        RHS.Distance = Distance;
        return RHS;
    }
    else
    {
        LHS.Distance = Distance;
        return LHS;
    }
}


// --------------
// Shape Operands
// --------------
    
ColorSDF Sphere(vec3 Point, float Radius, int PaintFn)
{
    return ColorSDF(sdSphere(Point, Radius), PaintFn, Point, vec3(Radius));
}


ColorSDF Box(vec3 Point, vec3 Extent, int PaintFn)
{
    return ColorSDF(sdBox(Point, Extent), PaintFn, Point, Extent);
}


ColorSDF Cylinder(vec3 Point, float Radius, float Length, int PaintFn)
{
    vec3 Extent = vec3(Radius, Length * 0.5, Radius);
    float CylinderPart = sdCylinder(Point, vec3(0.0, 0.0, Radius));
    float BoxPart = sdBox(Point, Extent);
    float Distance = opIntersection(CylinderPart, BoxPart);
    return ColorSDF(Distance, PaintFn, Point, Extent);
}
