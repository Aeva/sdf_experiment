
import sys
import re

vertgex = re.compile(r'^v\s(-?[-0-9.]+)\s(-?[-0-9.]+)\s(-?[-0-9.]+)$')
normgex = re.compile(r'^vn\s(-?[-0-9.]+)\s(-?[-0-9.]+)\s(-?[-0-9.]+)$')
facegex = re.compile(r'^f\s([0-9]+)//([0-9]+)\s([0-9]+)//([0-9]+)\s([0-9]+)//([0-9]+)$')


def block(glsl_type, name, vectors):
	out = f"{glsl_type} {name}[{len(vectors)}] = \\\n"
	out += "{\n"
	strs = (f"\t{glsl_type}({args})" for args in (', '.join(map(str, v)) for v in vectors))
	out += ',\n'.join(strs)
	out += "\n};"
	return out


if __name__ == "__main__":
	path = sys.argv[1]
	verts = []
	norms = []
	face_verts = []
	face_norms = []
	with open(path, 'r') as obj_file:
		for line in obj_file:
			if match := vertgex.match(line):
				verts.append([float(i) for i in match.groups()])
			elif match := normgex.match(line):
				norms.append([float(i) for i in match.groups()])
			elif match:= facegex.match(line):
				face = [int(i) - 1 for i in match.groups()]
				face_verts.append(face[::2])
				face_norms.append(face[1::2])
	out = [
		block("vec3", "Vertices", verts),
		block("vec3", "Normals", norms),
		block("ivec3", "VertexIndexes", face_verts),
		block("ivec3", "NormalIndexes", face_norms),
	]
	print("--------------------------------------------------------------------------------\n")
	print("\n\n\n".join(out))
