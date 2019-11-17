prepend: shaders/screen.glsl
prepend: shaders/sdf.glsl
--------------------------------------------------------------------------------

layout(location = 0) out vec4 OutColor;
layout(depth_any) out float gl_FragDepth;

layout(std140, binding = 5)
uniform ObjectInfoBlock
{
	mat4 LocalToWorld;
	mat4 WorldToLocal;
	int ShapeFn;
};


const vec3 LightPosition = vec3(0.0, 10.0, 20.0);


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
	ColorSDF Shape = Cylinder2(Point, Radius, Length, 2);
	Shape = Union(Shape, Cylinder2(RotateY(Point, RADIANS(90.0)), Radius, Length, 0));
	Shape = Union(Shape, Cylinder2(RotateX(Point, RADIANS(90.0)), Radius, Length, 1));
	return Shape;
}


ColorSDF FancyBox(vec3 Point)
{
	ColorSDF Cube = Box(Point, vec3(1.0), 3);
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
	ColorSDF Shape = Cut(Sphere(Point, 1.0, 4), Sphere((Point - Cut1), 1.5, 0));
	bool bEven = true;
	for (float Shell = 0.8; Shell >= 0.2; Shell-= 0.2)
	{
		bEven = !bEven;
		ColorSDF Next;
		ColorSDF ShellCut;
		if (bEven)
		{
			Next = Sphere(Point, Shell, 4);
			ShellCut = Sphere(Point - Cut2, 1.5, 0);
		}
		else
		{
			Next = Sphere(Point, Shell, 5);
			ShellCut = Sphere(Point - Cut3, 1.5, 0);
		}
		Shape = Cut(Shape, Next);
		Shape = Union(Cut(Shape, Next), Cut(Next, ShellCut));
	}
	return Shape;
}


ColorSDF SceneSDF(vec3 Point)
{
	vec3 Local = Transform3(WorldToLocal, Point);
	if (ShapeFn == 0)
	{
		return FancyBox(Local);
	}
	else if (ShapeFn == 1)
	{
		return Sphube(Local, 0.3, 0);
	}
	else if (ShapeFn == 2)
	{
		return Sphube(Local, 0.6, 1);
	}
	else if (ShapeFn == 3)
	{
		return Onion(Local);
	}
}


vec3 Illuminate(const vec3 BaseColor, const vec3 Point, const vec3 WorldNormal)
{
	const float CosAngle = dot(normalize(Point - LightPosition), WorldNormal);
	return BaseColor * max(-CosAngle, 0.5);
}


vec3 Paint(vec3 Point, ColorSDF Shape)
{
    // UVW should be about -1.0 to 1.0 in range, but may go over.
    const vec3 UVW = Shape.Local / Shape.Extent;

	//const vec3 WorldNormal = WorldNormalViaDerivatives(Point);
	const vec3 WorldNormal = WorldNormalViaGradient(Point);

	float Inner = max(min(-Shape.InnerDistance, 1.0), 0.0);
	Inner = sin(Inner * 35.0) * 0.5 + 0.5;
	Inner = round(Inner);

	if (Shape.PaintFn == 0)
	{
		return Illuminate(vec3(1.0, Inner, Inner), Point, WorldNormal);
	}
	else if (Shape.PaintFn == 1)
	{
		return Illuminate(vec3(Inner, 1.0, Inner), Point, WorldNormal);
	}
	else if (Shape.PaintFn == 2)
	{
		return Illuminate(vec3(Inner, Inner, 1.0), Point, WorldNormal);
	}
	else if (Shape.PaintFn == 3)
	{
		return Illuminate(vec3(1.0), Point, WorldNormal);
	}
	else if (Shape.PaintFn == 4)
	{
		return Illuminate(vec3(0.0, 0.0, 1.0), Point, WorldNormal);
	}
	else if (Shape.PaintFn == 5)
	{
		return Illuminate(vec3(0.088, 0.656, 0.939), Point, WorldNormal);
	}
    else if (Shape.PaintFn == -1)
    {
		discard;
    }
    else
    {
        return vec3(1.0, 0.0, 0.0);
    }   
}


void main()
{
    vec3 Position;
    ColorSDF Scene;
    RayTrace(Position, Scene);
	OutColor = vec4(Paint(Position, Scene), 1.0);
	gl_FragDepth = 1.0 / distance(Position, CameraOrigin.xyz);
}
