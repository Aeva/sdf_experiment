prepend: shaders/screen.glsl
prepend: shaders/sdf.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(depth_any) out float gl_FragDepth;


const vec3 LightPosition = vec3(0.0, 10.0, 20.0);


#define PAINT_DISCARD -1
#define PAINT_X_AXIS 0
#define PAINT_Y_AXIS 1
#define PAINT_Z_AXIS 2
#define PAINT_WHITE 3
#define PAINT_ONION1 4
#define PAINT_ONION2 5
#define PAINT_TANGERINE 6
#define PAINT_LIME 7
#define PAINT_FLOOR1 8
#define PAINT_FLOOR2 9
#define PAINT_WATER1 10
#define PAINT_WATER2 11
#define PAINT_TREE_TRUNK 12
#define PAINT_TREE_LEAVES 13

#define ENABLE_CUBETRACE 1


ColorSDF Sphube(vec3 Point, float Alpha, int PaintFn)
{
    ColorSDF a = Sphere(Point, 1.0, PaintFn);
    ColorSDF b = Box(Point, vec3(1.0), PaintFn);
    b.Distance = mix(a.Distance, b.Distance, Alpha);
	b.InnerDistance = mix(a.InnerDistance, b.InnerDistance, Alpha);
    return b;
}


ColorSDF Axes(vec3 Point, float Radius, float Length)
{
	ColorSDF Shape = Cylinder2(Point, Radius, Length, PAINT_Z_AXIS);
	Shape = Union(Shape, Cylinder2(RotateY(Point, RADIANS(90.0)), Radius, Length, PAINT_X_AXIS));
	Shape = Union(Shape, Cylinder2(RotateX(Point, RADIANS(90.0)), Radius, Length, PAINT_Y_AXIS));
	return Shape;
}


ColorSDF FancyBox(vec3 Point, vec3 Bounds)
{
	ColorSDF Cube = Box(Point, Bounds, PAINT_WHITE);
	ColorSDF Inlay = Axes(Point, 0.8, 2.0);
	ColorSDF Shape = Replace(Cube, Inlay);
	Shape = Cut(Shape, Sphere((Point - vec3(1.0, 1.0, 1.0)), 1.3, 0));
	return Shape;
}


ColorSDF Onion(vec3 Point)
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


ColorSDF TreeSDF(vec3 Local)
{
	const float TreeHeight = 10.0;
	const float FoliageOffset = 2.0;
	const float FoliageHeight = max(TreeHeight - FoliageOffset, 0.0);
	const vec3 FoliageLocal = Local - vec3(0.0, 0.0, FoliageOffset);

	ColorSDF Shape = Cylinder(Local, 0.5, TreeHeight, PAINT_TREE_TRUNK);
	Shape = Union(Shape, Cylinder(FoliageLocal, 2.0, FoliageHeight, PAINT_TREE_LEAVES));
	return Shape;
}


ColorSDF SceneSDF(vec3 Local)
{
	if (ShapeFn == 0)
	{
		return FancyBox(Local, ShapeBounds);
	}
	else if (ShapeFn == 1)
	{
		ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
		return Cut(Sphube(Local, 0.5, PAINT_TANGERINE), CutShape);
	}
	else if (ShapeFn == 2)
	{
		ColorSDF A = Sphere(Local - vec3(-0.25, 0.25, 0.0), 0.75, PAINT_LIME);
		ColorSDF B = Sphere(Local - vec3(0.25, -0.25, 0.0), 0.75, PAINT_LIME);
		ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
		return Cut(SmoothUnion(A, B, 0.1), CutShape);
	}
	else if (ShapeFn == 3)
	{
		return Onion(Local);
	}
	else if (ShapeFn >= 4 && ShapeFn <=7)
	{
		return CubeTraceSceneSDF(Local);
	}
	else if (ShapeFn == 8)
	{
		return TreeSDF(Local);
	}
}


ColorSDF CubeTraceSceneSDF(vec3 Local)
{
	if (ShapeFn == 4)
	{
		return Box(Local, ShapeBounds, PAINT_FLOOR1);
	}
	else if (ShapeFn == 5)
	{
		return Box(Local, ShapeBounds, PAINT_FLOOR2);
	}
	if (ShapeFn == 6)
	{
		return Box(Local, ShapeBounds, PAINT_WATER1);
	}
	else if (ShapeFn == 7)
	{
		return Box(Local, ShapeBounds, PAINT_WATER2);
	}
}


vec3 Illuminate(const vec3 BaseColor, const vec3 Point, const vec3 WorldNormal)
{
	const float CosAngle = dot(normalize(Point - LightPosition), WorldNormal);
	return BaseColor * max(-CosAngle, 0.5);
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


vec3 PaintTangerine(const ColorSDF Shape, const vec3 Flesh, const vec3 Fnord, const vec3 Rind)
{
	if (Shape.InnerDistance > -0.1)
	{
		return Rind;
	}
	else if (Shape.InnerDistance > -0.13)
	{
		return Fnord;
	}
	else
	{
		vec3 Test = vec3(abs(Shape.Local.x), -abs(Shape.Local.y), Shape.Local.z);
		ColorSDF Shape = Wedge(Test, 30.0);
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(30)), 30.0));
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(60)), 30.0));
		Shape = Union(Shape, Wedge(RotateZ(Test, RADIANS(90)), 30.0));
		if (IS_SOLID(Shape.Distance))
		{
			return Flesh;
		}
		return Fnord;
	}
}


vec3 PaintAxis(const ColorSDF Shape)
{
	float Inner = max(min(-Shape.InnerDistance, 1.0), 0.0);
	Inner = sin(Inner * 35.0) * 0.5 + 0.5;
	Inner = round(Inner);
	if (Shape.PaintFn == PAINT_X_AXIS)
	{
		return vec3(1.0, Inner, Inner);
	}
	else if (Shape.PaintFn == PAINT_Y_AXIS)
	{
		return vec3(Inner, 1.0, Inner);
	}
	else if (Shape.PaintFn == PAINT_Z_AXIS)
	{
		return vec3(Inner, Inner, 1.0);
	}
}


vec3 Paint(vec3 Point, ColorSDF Shape)
{
    // UVW should be about -1.0 to 1.0 in range, but may go over.
    const vec3 UVW = Shape.Local / Shape.Extent;

	//const vec3 WorldNormal = WorldNormalViaDerivatives(Point);
	const vec3 WorldNormal = WorldNormalViaGradient(Point);

	vec3 Color = vec3(0.0);

	if (Shape.PaintFn >= PAINT_X_AXIS && Shape.PaintFn <= PAINT_Z_AXIS)
	{
		Color = PaintAxis(Shape);
	}
	else if (Shape.PaintFn == PAINT_WHITE)
	{
		Color = vec3(1.0);
	}
	else if (Shape.PaintFn == PAINT_ONION1)
	{
		Color = vec3(0.0, 0.0, 1.0);
	}
	else if (Shape.PaintFn == PAINT_ONION2)
	{
		Color = vec3(0.088, 0.656, 0.939);
	}
	else if (Shape.PaintFn == PAINT_TANGERINE)
	{
		const vec3 Flesh = vec3(0.935, 0.453, 0.08);
		const vec3 Fnord = vec3(0.953, 0.891, 0.767);
		const vec3 Rind  = vec3(1.0, 0.767, 0.0);
		Color = PaintTangerine(Shape, Flesh, Fnord, Rind);
	}
	else if (Shape.PaintFn == PAINT_LIME)
	{
		const vec3 Flesh = vec3(0.651, 0.771, 0.137);
		const vec3 Fnord = vec3(0.89, 0.945, 0.71);
		const vec3 Rind  = vec3(0.552, 0.736, 0.193);
		Color = PaintTangerine(Shape, Flesh, Fnord, Rind);
	}
	else if (Shape.PaintFn == PAINT_FLOOR1)
	{
		Color = vec3(0.0, (Point.z + 2.0) / 2.0, 0.0);
	}
	else if (Shape.PaintFn == PAINT_FLOOR2)
	{
		Color = vec3(0.0, (Point.z + 2.0) / 2.0, 0.0) + 0.2;
	}
	else if (Shape.PaintFn == PAINT_WATER1)
	{
		Color = vec3(0.0, 0.0, abs(Point.z) / 2.0);
	}
	else if (Shape.PaintFn == PAINT_WATER2)
	{
		Color = vec3(0.0, 0.0, abs(Point.z) / 2.0) + 0.2;
	}
	else if (Shape.PaintFn == PAINT_TREE_TRUNK)
	{
		Color = vec3(0.627, 0.471, 0.094);
	}
	else if (Shape.PaintFn == PAINT_TREE_LEAVES)
	{
		Color = vec3(0.376, 0.784, 0.031);
	}
    else if (Shape.PaintFn == PAINT_DISCARD)
    {
		discard;
    }
    else
    {
        return vec3(1.0, 0.0, 0.0);
    }
	return Illuminate(Color, Point, WorldNormal);
}


void main()
{
    vec3 Position;
    ColorSDF Scene;
#if ENABLE_CUBETRACE
	if (ShapeFn == 4 || ShapeFn == 5)
	{
		CubeTrace(Position, Scene);
	}
	else
#endif
	{
		RayMarch(Position, Scene);
	}
	OutColor = vec4(Paint(Position, Scene), 1.0);
	gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
}
