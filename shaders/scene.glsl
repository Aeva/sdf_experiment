prepend: shaders/shapes.glsl
--------------------------------------------------------------------------------

float SceneHull(vec4 ShapeParams, vec3 Local)
{
	vec3 ShapeBounds = ShapeParams.xyz;
	int ShapeFn = int(ShapeParams.w);
	if (ShapeFn == SHAPE_ORIGIN)
	{
		return FancyBoxHull(Local, ShapeBounds);
	}
	else if (ShapeFn == SHAPE_X_AXIS)
	{
		return TangerineHull(Local);
	}
	else if (ShapeFn == SHAPE_Y_AXIS)
	{
		return LimeHull(Local);
	}
	else if (ShapeFn == SHAPE_Z_AXIS)
	{
		return OnionHull(Local);
	}
	else if (ShapeFn == SHAPE_TREE)
	{
		return TreeHull(Local);
	}
#if !ENABLE_CUBETRACE
	else if (ShapeFn > CUBE_TRACEABLES)
	{
		return sdBox(Local, ShapeBounds);
	}
#endif
}


ColorSDF SceneColor(vec4 ShapeParams, vec3 Local)
{
	vec3 ShapeBounds = ShapeParams.xyz;
	int ShapeFn = int(ShapeParams.w);
	if (ShapeFn == SHAPE_ORIGIN)
	{
		return FancyBoxColor(Local, ShapeBounds);
	}
	else if (ShapeFn == SHAPE_X_AXIS)
	{
		return TangerineColor(Local);
	}
	else if (ShapeFn == SHAPE_Y_AXIS)
	{
		return LimeColor(Local);
	}
	else if (ShapeFn == SHAPE_Z_AXIS)
	{
		return OnionColor(Local);
	}
	else if (ShapeFn == SHAPE_TREE)
	{
		return TreeColor(Local);
	}
#if !ENABLE_CUBETRACE
	else if (ShapeFn > CUBE_TRACEABLES)
	{
		return Box(Local, ShapeBounds, PAINT_CUBE);
	}
#endif
}


vec4 SceneTransmission(vec4 ShapeParams, vec3 Local)
{
	const vec3 ShapeBounds = ShapeParams.xyz;
	const int ShapeFn = int(ShapeParams.w);
	vec3 Color = vec3(0.0, 0.0, 0.0);
	float Step = 0.1;
	if (ShapeFn == SHAPE_X_AXIS)
	{
		Color = TangerineTransmission(Local);
	}
	return vec4(Color, Step);
}
