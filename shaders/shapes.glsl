prepend: shaders/objects.glsl
--------------------------------------------------------------------------------


struct ColorSDF
{
    float Distance;
	float InnerDistance;
    int PaintFn;
    vec3 Local;
    vec3 Extent;
};


const ColorSDF DiscardSDF = ColorSDF(0.0, 0.0, PAINT_DISCARD, vec3(0.0), vec3(0.0));


float SceneHull(vec4 ShapeParams, vec3 LocalPosition);
ColorSDF SceneColor(vec4 ShapeParams, vec3 LocalPosition);
vec4 SceneTransmission(vec4 ShapeParams, vec3 Local);


vec3 CubeWorldNormal(ObjectInfo Object, vec3 LocalPosition)
{
	const vec3 Mask = step(Object.ShapeParams.xyz, abs(LocalPosition) + AlmostZero);
	const vec3 LocalNormal = Mask * sign(LocalPosition.z);
	const vec3 CubeWorldCenter = Transform3(Object.LocalToWorld, vec3(0.0));
	return normalize(Transform3(Object.LocalToWorld, LocalNormal) - CubeWorldCenter);
}


#if USE_NORMALMETHOD == NORMALMETHOD_GRADIENT
vec3 WorldNormal(ObjectInfo Object, vec3 Point)
{
	const vec3 Local  = Transform3(Object.WorldToLocal, Point);
	const vec3 LocalM = Transform3(Object.WorldToLocal, Point - AlmostZero);
	const vec3 LocalP = Transform3(Object.WorldToLocal, Point + AlmostZero);
#define SDF(X, Y, Z) SceneHull(Object.ShapeParams, vec3(X, Y, Z))
	return normalize(vec3(
		SDF(LocalP.x, Local.y, Local.z) - SDF(LocalM.x, Local.y, Local.z),
		SDF(Local.x, LocalP.y, Local.z) - SDF(Local.x, LocalM.y, Local.z),
		SDF(Local.x, Local.y, LocalP.z) - SDF(Local.x, Local.y, LocalM.z)));
#undef SDF
}


#elif USE_NORMALMETHOD == NORMALMETHOD_DERIVATIVE
vec3 WorldNormal(ObjectInfo Object, vec3 Point)
{
	return normalize(cross(dFdx(Point), dFdy(Point)));
}


#endif //NORMAL_METHOD


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
    return length(p) - s;
}


float sdBox(vec3 p, vec3 b)
{
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}


float sdCylinder(vec3 p, float Radius)
{
    return length(p.xy) - Radius;
}


float opUnion(float d1, float d2)
{
    return min(d1, d2);
}


float opSubtraction(float d1, float d2)
{
    return max(d1, -d2);
}


float opIntersection(float d1, float d2)
{
    return max(d1, d2);
}


float opSmoothUnion(float d1, float d2, float k)
{
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}


float sdGloop(vec3 Point, float Scale)
{
	return sin(Scale * Point.x) * sin(Scale * Point.y) * sin(Scale * Point.z);
}


vec3 Twist(vec3 Point, float Intensity)
{
	float C = cos(Intensity * Point.z);
    float S = sin(Intensity * Point.z);
    mat2  M = mat2(C, -S, S, C);
    return vec3(M * Point.xy, Point.z);
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


ColorSDF Wedge(vec3 Point, float Angle)
{
	const float Alpha = min(abs(Angle) / 180.0, 1.0);
	const float Rad = mix(RADIANS(90.0), 0.0, Alpha);
	const float RotateA = RotateZ(Point, Rad).y;
	const float RotateB = RotateZ(Point, -Rad).y;
	const float Distance = max(RotateA, RotateB);
	return Inset(ColorSDF(Distance, Distance, 0, Point, vec3(1.0, 1.0, 1.0)), 0.02);
}


ColorSDF SphubeColor(vec3 Point, float Alpha, int PaintFn)
{
    ColorSDF a = Sphere(Point, 1.0, PaintFn);
    ColorSDF b = Box(Point, vec3(1.0), PaintFn);
    b.Distance = mix(a.Distance, b.Distance, Alpha);
	b.InnerDistance = mix(a.InnerDistance, b.InnerDistance, Alpha);
    return b;
}


float SphubeHull(vec3 Point, float Alpha, int PaintFn)
{
    return mix(sdSphere(Point, 1.0), sdBox(Point, vec3(1.0)), Alpha);
}


ColorSDF Axes(vec3 Point, float Radius, float Length)
{
	ColorSDF Shape = Cylinder2(Point, Radius, Length, PAINT_Z_AXIS);
	Shape = Union(Shape, Cylinder2(RotateY(Point, RADIANS(90.0)), Radius, Length, PAINT_X_AXIS));
	Shape = Union(Shape, Cylinder2(RotateX(Point, RADIANS(90.0)), Radius, Length, PAINT_Y_AXIS));
	return Shape;
}


ColorSDF FancyBoxColor(vec3 Point, vec3 Bounds)
{
	ColorSDF Cube = Box(Point, Bounds, PAINT_WHITE);
	ColorSDF Inlay = Axes(Point, 0.8, 2.0);
	ColorSDF Shape = Replace(Cube, Inlay);
	return Shape;
}


float FancyBoxHull(vec3 Point, vec3 Bounds)
{
	return opSubtraction(
		sdBox(Point, Bounds),
		sdSphere(Point - vec3(1.0, 1.0, 1.0), 1.3));
}


#define SLICES 1
#define TWIST_COLOR 0
#define TWIST_HULL 0
#define DISSOLVE 0
ColorSDF TangerineColor(vec3 Local)
{
#if TWIST_COLOR
	Local = Twist(Local, length(Local.xy) * 5.0);
#endif // TWIST_COLOR
	return SphubeColor(Local, 0.5, PAINT_TANGERINE);
}


float TangerineHull(vec3 Local)
{
#if ENABLE_HOVERING_SHAPES
	const float CounterZ = (-sin(Time * 2.0 + 1.0) + 0.5) / 2.5;
	vec3 BoxLocal = Local - vec3(0.0, 0.0, CounterZ);
#else
	vec3 BoxLocal = Local;
#endif // ENABLE_HOVERING_SHAPES
#if SLICES
	const float Repeat = 0.5;
	BoxLocal.z = mod(BoxLocal.z + 0.5 * Repeat, Repeat) - 0.5 * Repeat;
#endif // SLICES
#if TWIST_HULL
	Local = Twist(Local, length(Local.xy) * 5.0);
#endif // TWIST_HULL
	float Dist = SphubeHull(Local, 0.5, PAINT_TANGERINE);
#if DISSOLVE
	Dist = opIntersection(Dist, sdGloop(Local, 10.0));
#endif // DISSOLVE
#if SLICES
	Dist = opSubtraction(Dist, sdBox(BoxLocal, vec3(2.0, 2.0, Repeat * 0.3)));
#else
	Dist = opSubtraction(Dist, -Local.z);
#endif //SLICES
	return Dist;
}


vec3 TangerineTransmission(vec3 Local)
{
#if TWIST_COLOR
	Local = Twist(Local, length(Local.xy) * 5.0);
#endif // TWIST_COLOR
	float Dist = SphubeHull(Local, 0.5, PAINT_TANGERINE);
	if (Dist > -0.1)
	{
		return vec3(0.99, 0.0, 0.0);
	}
	else
	{
		return vec3(0.999, 0.0, 0.0);
	}
}
#undef SLICES
#undef TWIST_COLOR
#undef TWIST_HULL
#undef DISSOLVE


ColorSDF LimeColor(vec3 Local)
{
	ColorSDF A = Sphere(Local - vec3(-0.25, 0.25, 0.0), 0.75, PAINT_LIME);
	ColorSDF B = Sphere(Local - vec3(0.25, -0.25, 0.0), 0.75, PAINT_LIME);
	return SmoothUnion(A, B, 0.1);
}


float LimeHull(vec3 Local)
{
	float SpheresPart = opSmoothUnion(
		sdSphere(Local - vec3(-0.25, 0.25, 0.0), 0.75),
		sdSphere(Local - vec3(0.25, -0.25, 0.0), 0.75),
		0.1);
	return opIntersection(SpheresPart, Local.z);
}


ColorSDF OnionColor(vec3 Point)
{
	vec3 Cut1 = vec3(0.8, 1.2, 0.4);
	vec3 Cut2 = vec3(1.4, 0.8, 0.5);
	vec3 Cut3 = vec3(0.7, 1.4, 0.3);
	ColorSDF Shape = Cut(Sphere(Point, 1.0, PAINT_ONION1), Sphere((Point - Cut1), 1.5, 0));
	bool bEven = true;
	for (float Shell = 0.8; Shell >= 0.2; Shell-= 0.2)
	{
		bEven = !bEven;
		ColorSDF Next;
		ColorSDF ShellCut;
		if (bEven)
		{
			Next = Sphere(Point, Shell, PAINT_ONION1);
			ShellCut = Sphere(Point - Cut2, 1.5, 0);
		}
		else
		{
			Next = Sphere(Point, Shell, PAINT_ONION2);
			ShellCut = Sphere(Point - Cut3, 1.5, 0);
		}
		Shape = Cut(Shape, Next);
		Shape = Union(Cut(Shape, Next), Cut(Next, ShellCut));
	}
	return Shape;
}


float OnionHull(vec3 Point)
{
	vec3 Cut1 = Point - vec3(0.8, 1.2, 0.4);
	vec3 Cut2 = Point - vec3(1.4, 0.8, 0.5);
	vec3 Cut3 = Point - vec3(0.7, 1.4, 0.3);
	float Shape = opSubtraction(sdSphere(Point, 1.0), sdSphere((Cut1), 1.5));
	bool bEven = true;
	for (float Shell = 0.8; Shell >= 0.2; Shell-= 0.2)
	{
		bEven = !bEven;
		float Next = sdSphere(Point, Shell);
		float ShellCut;
		if (bEven)
		{
			ShellCut = sdSphere(Cut2, 1.5);
		}
		else
		{
			ShellCut = sdSphere(Cut3, 1.5);
		}
		Shape = opSubtraction(Shape, Next);
		Shape = opUnion(opSubtraction(Shape, Next), opSubtraction(Next, ShellCut));
	}
	return Shape;
}


const float TreeHeight = 10.0;

const float FoliageOffset = 2.0;
const float FoliageHeight = TreeHeight - FoliageOffset;
const float FoliageRadius = 2.0;
const float FoliageSlope = -FoliageHeight / FoliageRadius;
const float FoliageRatio = sqrt(1.0/(FoliageSlope * FoliageSlope + 1.0));
const vec3 FoliageTranslate = vec3(0.0, 0.0, -TreeHeight * 0.5 + FoliageOffset);
const vec3 FoliageExtent = vec3(FoliageRadius, FoliageRadius, FoliageHeight) * 0.5;

const float TrunkHalfHeight = FoliageOffset * 0.5;
const float TrunkRadius = 0.5;
const vec3 TrunkTranslate = vec3(0.0, 0.0, -TreeHeight * 0.5 + TrunkHalfHeight);
const vec3 TrunkExtent = vec3(TrunkRadius, TrunkRadius, TrunkHalfHeight);


float FoliageHull(const vec3 Local)
{
	const vec2 Test = vec2(abs(length(Local.xy)), Local.z - FoliageTranslate.z);
	const float Vertical = (FoliageSlope * Test.x + FoliageHeight - Test.y);
    const float Perpendicular = Vertical * FoliageRatio;
    return -min(Perpendicular, Test.y);
}


ColorSDF FoliageColor(const vec3 Local)
{
	const float Distance = FoliageHull(Local);
	return ColorSDF(Distance, Distance, PAINT_TREE_LEAVES, Local - FoliageTranslate, FoliageExtent);
}


float TreeTrunkHull(const vec3 Local)
{
    const float CylinderPart = sdCylinder(Local-TrunkTranslate, TrunkRadius);
    const float BoxPart = sdBox(Local-TrunkTranslate, TrunkExtent);
    return opIntersection(CylinderPart, BoxPart);
}


ColorSDF TreeTrunkColor(const vec3 Local)
{
    const float Distance = TreeTrunkHull(Local);
	return ColorSDF(Distance, Distance, PAINT_TREE_TRUNK, Local - TrunkTranslate, TrunkExtent);
}


float TreeHull(const vec3 Local)
{
	return opUnion(FoliageHull(Local), TreeTrunkHull(Local));
	return FoliageHull(Local);
}


ColorSDF TreeColor(vec3 Local)
{
	return Union(FoliageColor(Local), TreeTrunkColor(Local));
}
