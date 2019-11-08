uniform mat4 view;
uniform mat4 modelMatrix;

#ifdef VERTEX
vec4 position(mat4 transformProjection, vec4 vertexPosition) {
	vec4 pos = view * modelMatrix * vertexPosition;
	return pos;
}
#endif

#ifdef PIXEL
void effect() {
	love_Canvases[0] = VaryingColor;
}
#endif
