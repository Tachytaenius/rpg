uniform mat4 view;
uniform mat4 modelMatrix;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
	vec4 pos = view * modelMatrix * vertexPosition;
	return pos;
}
