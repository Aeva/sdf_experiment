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


float SceneHull(vec3 LocalPosition);
ColorSDF SceneColor(vec3 LocalPosition);


vec3 CubeWorldNormal(vec3 LocalPosition)
{
	const vec3 Mask = step(ShapeBounds, abs(LocalPosition) + AlmostZero);
	const vec3 LocalNormal = Mask * sign(LocalPosition.z);
	const vec3 CubeWorldCenter = Transform3(LocalToWorld, vec3(0.0));
	return normalize(Transform3(LocalToWorld, LocalNormal) - CubeWorldCenter);
}


#if USE_NORMALMETHOD == NORMALMETHOD_GRADIENT
vec3 WorldNormal(vec3 Point)
{
	const vec3 Local  = Transform3(WorldToLocal, Point);
	const vec3 LocalM = Transform3(WorldToLocal, Point - AlmostZero);
	const vec3 LocalP = Transform3(WorldToLocal, Point + AlmostZero);
#define SDF(X, Y, Z) SceneHull(vec3(X, Y, Z))
	return normalize(vec3(
		SDF(LocalP.x, Local.y, Local.z) - SDF(LocalM.x, Local.y, Local.z),
		SDF(Local.x, LocalP.y, Local.z) - SDF(Local.x, LocalM.y, Local.z),
		SDF(Local.x, Local.y, LocalP.z) - SDF(Local.x, Local.y, LocalM.z)));
#undef SDF
}


#elif USE_NORMALMETHOD == NORMALMETHOD_DERIVATIVE
vec3 WorldNormal(vec3 Point)
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
	Shape = Cut(Shape, Sphere((Point - vec3(1.0, 1.0, 1.0)), 1.3, 0));
	return Shape;
}


float FancyBoxHull(vec3 Point, vec3 Bounds)
{
	return opSubtraction(
		sdBox(Point, Bounds),
		sdSphere(Point - vec3(1.0, 1.0, 1.0), 1.3));
}


ColorSDF TangerineColor(vec3 Local)
{
	ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
	return Cut(SphubeColor(Local, 0.5, PAINT_TANGERINE), CutShape);
}


float TangerineHull(vec3 Local)
{
	return opIntersection(
		SphubeHull(Local, 0.5, PAINT_TANGERINE),
		Local.z);
}


ColorSDF LimeColor(vec3 Local)
{
	ColorSDF A = Sphere(Local - vec3(-0.25, 0.25, 0.0), 0.75, PAINT_LIME);
	ColorSDF B = Sphere(Local - vec3(0.25, -0.25, 0.0), 0.75, PAINT_LIME);
	ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
	return Cut(SmoothUnion(A, B, 0.1), CutShape);
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


ColorSDF TreeColor(vec3 Local)
{
	const float TreeHeight = 10.0;
	const float FoliageOffset = 2.0;
	const float FoliageHeight = max(TreeHeight - FoliageOffset, 0.0);
	const vec3 FoliageLocal = Local - vec3(0.0, 0.0, FoliageOffset);

	ColorSDF Shape = Cylinder(Local, 0.5, TreeHeight, PAINT_TREE_TRUNK);
	Shape = Union(Shape, Cylinder(FoliageLocal, 2.0, FoliageHeight, PAINT_TREE_LEAVES));
	return Shape;
}


float TreeHull(vec3 Local)
{
	return TreeColor(Local).Distance;
}
