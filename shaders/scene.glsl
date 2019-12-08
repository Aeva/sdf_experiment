--------------------------------------------------------------------------------

ColorSDF SceneSDF(vec3 Local)
{
	if (ShapeFn == SHAPE_ORIGIN)
	{
		return FancyBox(Local, ShapeBounds);
	}
	else if (ShapeFn == SHAPE_X_AXIS)
	{
		ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
		return Cut(Sphube(Local, 0.5, PAINT_TANGERINE), CutShape);
	}
	else if (ShapeFn == SHAPE_Y_AXIS)
	{
		ColorSDF A = Sphere(Local - vec3(-0.25, 0.25, 0.0), 0.75, PAINT_LIME);
		ColorSDF B = Sphere(Local - vec3(0.25, -0.25, 0.0), 0.75, PAINT_LIME);
		ColorSDF CutShape = ColorSDF(-Local.z, -Local.z, 0, Local, vec3(1.0, 1.0, 1.0));
		return Cut(SmoothUnion(A, B, 0.1), CutShape);
	}
	else if (ShapeFn == SHAPE_Z_AXIS)
	{
		return Onion(Local);
	}
	else if (ShapeFn > CUBE_TRACEABLES)
	{
		return CubeTraceSceneSDF(Local);
	}
	else if (ShapeFn == SHAPE_TREE)
	{
		return TreeSDF(Local);
	}
}


ColorSDF CubeTraceSceneSDF(vec3 Local)
{
	if (ShapeFn == SHAPE_GRASS_CUBE_1)
	{
		return Box(Local, ShapeBounds, PAINT_FLOOR1);
	}
	else if (ShapeFn == SHAPE_GRASS_CUBE_2)
	{
		return Box(Local, ShapeBounds, PAINT_FLOOR2);
	}
	if (ShapeFn == SHAPE_WATER_CUBE_1)
	{
		return Box(Local, ShapeBounds, PAINT_WATER1);
	}
	else if (ShapeFn == SHAPE_WATER_CUBE_2)
	{
		return Box(Local, ShapeBounds, PAINT_WATER2);
	}
}
