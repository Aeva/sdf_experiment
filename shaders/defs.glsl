
// NOTE: This file must be both valid GLSL and C++!

// --------------------
// SHAPE FUNCTION NAMES
// --------------------
#define SHAPE_ORIGIN 0
#define SHAPE_X_AXIS 1
#define SHAPE_Y_AXIS 2
#define SHAPE_Z_AXIS 3
#define SHAPE_TREE 4
#define CUBE_TRACEABLES 100
#define SHAPE_GRASS_CUBE_1 101
#define SHAPE_GRASS_CUBE_2 102
#define SHAPE_WATER_CUBE_1 103
#define SHAPE_WATER_CUBE_2 104

// --------------------
// PAINT FUNCTION NAMES
// --------------------
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

// --------------------------
// CONFIGURATION OPTION NAMES
// --------------------------
#define RAYMETHOD_BASIC 1
#define RAYMETHOD_CUBE_ELIMINATE 2
#define RAYMETHOD_COVERAGE_SEARCH 3
#define NORMALMETHOD_GRADIENT 1
#define NORMALMETHOD_DERIVATIVE 2

// ------------------------
// CONFIGURATION PARAMETERS
// ------------------------
#define ENABLE_CUBETRACE 1
#define USE_RAYMETHOD RAYMETHOD_COVERAGE_SEARCH
#define USE_NORMALMETHOD NORMALMETHOD_GRADIENT

// ----------------
// COMMON CONSTANTS
// ----------------
const int MaxIterations = 100;
const float AlmostZero = 0.001;
