varying vec3 normal;
varying vec3 fragmentPosition;

#ifdef VERTEX
	uniform mat4 view;
	uniform mat4 modelMatrix;
	uniform mat4 modelMatrixInverse;
	
	attribute vec4 VertexNormal;
	
	vec4 position(mat4 transformProjection, vec4 vertexPosition) {
		normal = -vec3(modelMatrixInverse * VertexNormal); // TODO: I don't know why these are negated. It's not important for now.
		fragmentPosition = vec3(modelMatrix * vertexPosition);
		
		return view * modelMatrix * vertexPosition;
	}
#endif

#ifdef PIXEL
	mat3 cotangentFrame(vec3 n, vec3 p, vec2 st) {
		vec3 dp1 = dFdx(p);
		vec3 dp2 = dFdy(p);
		vec2 dst1 = dFdx(st);
		vec2 dst2 = dFdy(st);
		
		vec3 dp2perp = cross(dp2, n);
		vec3 dp1perp = cross(n, dp1);
		vec3 t = dp2perp * dst1.s + dp1perp * dst2.s;
		vec3 b = dp2perp * dst1.t + dp1perp * dst2.t;
		
		float invmax = inversesqrt(max(dot(t, t), dot(b, b)));
		return mat3(t * invmax, b * invmax, n);
	}
	
	vec3 perturbNormal(vec3 fragNormal, vec3 mapNormal, vec2 st, vec3 v) {
		mapNormal.y*=-1; // TODO inverse y i guess
		mat3 tbn = cotangentFrame(fragNormal, -v, st);
		return normalize(tbn * mapNormal);
	}
	
	uniform vec3 viewPosition;
	
	uniform Image albedoMap;
	uniform Image materialMap;
	uniform Image surfaceMap;
	
	void effect() {
		vec2 textureCoords = vec2(VaryingTexCoord);
		love_Canvases[0] = vec4(fragmentPosition, 1);
		vec4 surfaceTexel = Texel(surfaceMap, textureCoords);
		love_Canvases[1] = vec4(perturbNormal(normal, surfaceTexel.rgb * 2 - 1, textureCoords, normalize(viewPosition - fragmentPosition)), 1);
		love_Canvases[2] = Texel(albedoMap, textureCoords);
		love_Canvases[3] = Texel(materialMap, textureCoords);
	}
#endif
