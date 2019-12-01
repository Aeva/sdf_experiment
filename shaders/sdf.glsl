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


in vec4 gl_FragCoord;
in flat mat4 LocalToWorld;
in flat mat4 WorldToLocal;
in flat vec2 DepthRange;
in flat vec3 ShapeBounds;
in flat int ShapeFn;


const vec3 UpVector = vec3(0.0, 0.0, 1.0);
const int MaxIterations = 100;
const float AlmostZero = 0.001;


struct ColorSDF
{
    float Distance;
	float InnerDistance;
    int PaintFn;
    vec3 Local;
    vec3 Extent;
};


const ColorSDF DiscardSDF = ColorSDF(0.0, 0.0, -1, vec3(0.0), vec3(0.0));


ColorSDF SceneSDF(vec3 LocalPosition);
ColorSDF CubeTraceSceneSDF(vec3 LocalPosition);


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


vec3 WorldNormalViaGradient(vec3 Point)
{
	const vec3 Local  = Transform3(WorldToLocal, Point);
	const vec3 LocalM = Transform3(WorldToLocal, Point - AlmostZero);
	const vec3 LocalP = Transform3(WorldToLocal, Point + AlmostZero);
#define SDF(X, Y, Z) SceneSDF(vec3(X, Y, Z)).Distance
	return normalize(vec3(
		SDF(LocalP.x, Local.y, Local.z) - SDF(LocalM.x, Local.y, Local.z),
		SDF(Local.x, LocalP.y, Local.z) - SDF(Local.x, LocalM.y, Local.z),
		SDF(Local.x, Local.y, LocalP.z) - SDF(Local.x, Local.y, LocalM.z)));
#undef SDF
}


vec3 WorldNormalViaDerivatives(vec3 Point)
{
	return normalize(cross(dFdx(Point), dFdy(Point)));
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


vec3 GetStartPosition(const vec3 RayDir)
{
	const float Fudge = 0.2;
	return RayDir * max(DepthRange.x - Fudge, 0.0) + CameraOrigin.xyz;
}


void CubeTrace(out vec3 Position, out ColorSDF Scene)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);

	const vec3 BoxExtent = ShapeBounds;

	if (abs(LocalRayStart.x) <= BoxExtent.x &&
		abs(LocalRayStart.y) <= BoxExtent.y &&
		abs(LocalRayStart.z) <= BoxExtent.z)
	{
		Position = WorldRayStart;
		Scene = CubeTraceSceneSDF(LocalRayStart);
		return;
	}

	const vec3 Fnord1 = (-BoxExtent - LocalRayStart) / LocalRayDir;
	const vec3 Fnord2 = (BoxExtent - LocalRayStart) / LocalRayDir;
	float RayDists[6] = \
	{
		Fnord1.x,
		Fnord1.y,
		Fnord1.z,
		Fnord2.x,
		Fnord2.y,
		Fnord2.z
	};

	for (int t = 0; t < 5; ++t)
	{
		for (int i = 0; i < 5; ++i)
		{
			const float a = RayDists[i];
			const float b = RayDists[i+1];
			RayDists[i] = min(a, b);
			RayDists[i+1] = max(a, b);
		}
	}

	for (int i = 0; i < 3; ++i)
	{
		const vec3 LocalPosition = RayDists[i] * LocalRayDir + LocalRayStart;
		Scene = CubeTraceSceneSDF(LocalPosition);
		if (IS_SOLID(Scene.Distance))
		{
			Position = Transform3(LocalToWorld, LocalPosition);
			return;
		}
	}

	Position = vec3(0.0);
	Scene = DiscardSDF;
}


#if 0
void RayMarch(out vec3 Position, out ColorSDF Scene)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	vec3 LocalPosition = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalPosition);
	const vec3 LocalCameraOrigin = Transform3(WorldToLocal, CameraOrigin.xyz);

	for (int Step = 0; Step <= MaxIterations; ++Step)
    {
		Scene = SceneSDF(LocalPosition);
		LocalPosition += LocalRayDir * Scene.Distance;
		if (IS_SOLID(Scene.Distance))
        {
			Scene = SceneSDF(LocalPosition);
			if (Scene.InnerDistance == Scene.Distance)
			{
				Scene.InnerDistance = 0.0;
			}
			Scene.Distance = 0.0;
			Position = Transform3(LocalToWorld, LocalPosition);
			return;
        }
		if (distance(LocalPosition, LocalCameraOrigin) > DepthRange.y)
		{
			break;
		}
    }
	Position = vec3(0.0);
	Scene.PaintFn = -1;
}
#else
float sdBox(vec3 p, vec3 b);
void RayMarch(out vec3 Position, out ColorSDF Scene)
{
	const vec3 WorldRayDir = GetRayDir();
	const vec3 WorldRayStart = GetStartPosition(WorldRayDir);
	const vec3 LocalRayStart = Transform3(WorldToLocal, WorldRayStart);
	const vec3 LocalRayDir = normalize(Transform3(WorldToLocal, WorldRayStart + WorldRayDir) - LocalRayStart);

	const vec3 BoxExtent = ShapeBounds;

	if (abs(LocalRayStart.x) <= BoxExtent.x &&
		abs(LocalRayStart.y) <= BoxExtent.y &&
		abs(LocalRayStart.z) <= BoxExtent.z)
	{
		Position = WorldRayStart;
		Scene = SceneSDF(LocalRayStart);
		return;
	}

	const vec3 Fnord1 = (-BoxExtent - LocalRayStart) / LocalRayDir;
	const vec3 Fnord2 = (BoxExtent - LocalRayStart) / LocalRayDir;
	float RayDists[6] = \
	{
		Fnord1.x,
		Fnord1.y,
		Fnord1.z,
		Fnord2.x,
		Fnord2.y,
		Fnord2.z
	};

	for (int t = 0; t < 5; ++t)
	{
		for (int i = 0; i < 5; ++i)
		{
			const float a = RayDists[i];
			const float b = RayDists[i+1];
			RayDists[i] = min(a, b);
			RayDists[i+1] = max(a, b);
		}
	}

	bool bFound = false;
	float RayDistance;
	for (int i = 0; i < 3; ++i)
	{
		vec3 LocalPosition = RayDists[i] * LocalRayDir + LocalRayStart;
		if (IS_SOLID(sdBox(LocalPosition, BoxExtent)))
		{
			RayDistance = RayDists[i];
			bFound = true;
			break;
		}
	}
	if (bFound)
	{
		const float EndRayDist = RayDists[5];
		for (int Step = 0; Step <= MaxIterations; ++Step)
	    {
			vec3 LocalPosition = RayDistance * LocalRayDir + LocalRayStart;
			Scene = SceneSDF(LocalPosition);
			RayDistance += Scene.Distance;
			if (IS_SOLID(Scene.Distance))
			{
				Scene = SceneSDF(LocalPosition);
				if (Scene.InnerDistance == Scene.Distance)
				{
					Scene.InnerDistance = 0.0;
				}
				Scene.Distance = 0.0;
				Position = Transform3(LocalToWorld, LocalPosition);
				return;
			}
			else if (RayDistance > EndRayDist)
			{
				break;
			}
		}
	}
	Position = vec3(0.0);
	Scene = DiscardSDF;
}
#endif


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


float sdCylinder(vec3 p, float Radius)
{
    return length(p.xy)-Radius;
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


float opSmoothUnion(float d1, float d2, float k)
{
    float h = clamp(0.5 + 0.5 * (d2-d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}


// ---------------
// Shape Operators
// ---------------

ColorSDF Union(ColorSDF LHS, ColorSDF RHS)
{
    if (LHS.Distance == opUnion(LHS.Distance, RHS.Distance))
    {
        return LHS;
    }
    else
    {
        return RHS;
    }
}


ColorSDF Intersection(ColorSDF LHS, ColorSDF RHS)
{
    if (LHS.Distance == opIntersection(LHS.Distance, RHS.Distance))
    {
        return LHS;
    }
    else
    {
        return RHS;
    }
}


ColorSDF Replace(ColorSDF LHS, ColorSDF RHS)
{
    float Combined = opIntersection(LHS.Distance, RHS.Distance);
    if (IS_SOLID(Combined))
    {
        RHS.Distance = Combined;
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
    if (LHS.Distance == opSubtraction(LHS.Distance, RHS.Distance))
    {
        return LHS;
    }
    else
    {
        return RHS;
    }
}


// "Spack" as in "to apply spackle"
ColorSDF Spack(ColorSDF Brick, ColorSDF Spackle)
{
	return Union(Brick, Cut(Spackle, Brick));
}


ColorSDF Inset(ColorSDF Shape, float Distance)
{
	Shape.Distance += Distance;
	Shape.InnerDistance += Distance;
	return Shape;
}


ColorSDF SmoothUnion(ColorSDF LHS, ColorSDF RHS, float Threshold)
{
	float Combined = opSmoothUnion(LHS.Distance, RHS.Distance, Threshold);
	float InnerCombined = opSmoothUnion(LHS.InnerDistance, RHS.InnerDistance, Threshold);
	if (LHS.Distance <= RHS.Distance)
    {
		LHS.Distance = Combined;
		LHS.InnerDistance = InnerCombined;
		return LHS;
	}
	else
	{
		RHS.Distance = Combined;
		RHS.InnerDistance = InnerCombined;
		return RHS;
	}
}


// --------------
// Shape Operands
// --------------
    
ColorSDF Sphere(vec3 Point, float Radius, int PaintFn)
{
	float Distance = sdSphere(Point, Radius);
    return ColorSDF(Distance, Distance, PaintFn, Point, vec3(Radius));
}


ColorSDF Box(vec3 Point, vec3 Extent, int PaintFn)
{
	float Distance = sdBox(Point, Extent);
    return ColorSDF(Distance, Distance, PaintFn, Point, Extent);
}


ColorSDF Cylinder(vec3 Point, float Radius, float Length, int PaintFn)
{
    vec3 Extent = vec3(Radius, Radius, Length * 0.5);
    float CylinderPart = sdCylinder(Point, Radius);
    float BoxPart = sdBox(Point, Extent);
    float Distance = opIntersection(CylinderPart, BoxPart);
    return ColorSDF(Distance, Distance, PaintFn, Point, Extent);
}

ColorSDF Cylinder2(vec3 Point, float Radius, float Length, int PaintFn)
{
    vec3 Extent = vec3(Radius, Radius, Length * 0.5);
    float CylinderPart = sdCylinder(Point, Radius);
    float BoxPart = sdBox(Point, Extent);
    float Distance = opIntersection(CylinderPart, BoxPart);
    return ColorSDF(Distance, CylinderPart, PaintFn, Point, Extent);
}
