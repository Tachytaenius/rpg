const int maxGroups = 4;

varying vec3 fragmentNormal;
varying vec3 fragmentPosition;
varying float textureIndex;

#ifdef VERTEX
	uniform mat4 view;
	uniform mat4[maxGroups] modelMatrices;
	uniform mat4[maxGroups] modelMatrixInverses;
	
	attribute vec4 VertexNormal;
	// attribute int vertexTextureIndex;
	attribute float vertexTextureIndex;
	
	attribute float vertexGroup;
	
	vec4 position(mat4 transformProjection, vec4 vertexPosition) {
		fragmentNormal = -vec3(modelMatrixInverses[int(vertexGroup)] * VertexNormal); // TODO: I don't know why these are negated. It's not important for now.
		fragmentPosition = vec3(modelMatrices[int(vertexGroup)] * vertexPosition);
		textureIndex = vertexTextureIndex;
		
		return view * modelMatrices[int(vertexGroup)] * vertexPosition;
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
	
	uniform vec3 textureSize;
	uniform vec3 viewPosition;
	uniform float numTextures;
	uniform sampler3D diffuseMap;
	uniform sampler3D materialMap;
	uniform sampler3D surfaceMap;
	
	void effect() {
		vec3 textureCoords = mod(fragmentPosition-0.0001, textureSize) / textureSize;
		textureCoords.y += textureIndex;
		textureCoords.y /= numTextures;
		vec4 surfaceTexel = Texel(surfaceMap, textureCoords);
		vec3 mapNormal = surfaceTexel.rgb;
		float ambientIllumination = surfaceTexel.a;
		vec4 diffuseTexel = Texel(diffuseMap, textureCoords);
		vec4 materialTexel = Texel(materialMap, textureCoords);
		
		// vec3 outNormal = perturbNormal(fragmentNormal, mapNormal * 2 - 1, textureCoords, normalize(viewPosition - fragmentPosition));
		vec3 outNormal = fragmentNormal;
		
		love_Canvases[0] = vec4(fragmentPosition, 1);
		love_Canvases[1] = vec4(outNormal, ambientIllumination);
		love_Canvases[2] = diffuseTexel;
		love_Canvases[3] = materialTexel;
	}
#endif
