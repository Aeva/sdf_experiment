--------------------------------------------------------------------------------

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


vec3 Illuminate(const vec3 BaseColor, const vec3 Point, const vec3 WorldNormal)
{
	const vec3 LightPosition = vec3(0.0, 10.0, 20.0);
	const float CosAngle = dot(normalize(Point - LightPosition), WorldNormal);
	return BaseColor * max(-CosAngle, 0.5);
}


vec3 Paint(vec3 Point, ColorSDF Shape)
{
    // UVW should be about -1.0 to 1.0 in range, but may go over.
    const vec3 UVW = Shape.Local / Shape.Extent;

	const vec3 WorldNormal = WorldNormal(Point);

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
		//Color = vec3(0.0, (Point.z + 2.0) / 2.0, 0.0);
		Color = vec3(0.0, 0.75, 0.0);
	}
	else if (Shape.PaintFn == PAINT_FLOOR2)
	{
		//Color = vec3(0.0, (Point.z + 2.0) / 2.0, 0.0) + 0.2;
		Color = vec3(0.0, 0.5, 0.0);
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