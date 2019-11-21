const int maxGroups = 4;

uniform mat4 view;
uniform mat4[maxGroups] modelMatrices;

attribute float vertexGroup;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
	vec4 pos = view * modelMatrices[int(vertexGroup)] * vertexPosition;
	return pos;
}
