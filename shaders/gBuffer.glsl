varying vec3 fragmentNormal;
varying vec3 fragmentPosition;
// flat in int damage;
varying float damage;

uniform bool damageOverlays;

#ifdef VERTEX
	uniform mat4 view;
	uniform mat4 modelMatrix;
	uniform mat4 modelMatrixInverse;
	
	attribute vec4 VertexNormal;
	// attribute int vertexDamage;
	attribute float vertexDamage; 
	
	vec4 position(mat4 transformProjection, vec4 vertexPosition) {
		fragmentNormal = -vec3(modelMatrixInverse * VertexNormal); // TODO: I don't know why these are negated. It's not important for now.
		fragmentPosition = vec3(modelMatrix * vertexPosition);
		damage = vertexDamage;
		
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
	
	uniform Image diffuseMap;
	uniform Image materialMap;
	uniform Image surfaceMap;
	
	uniform float damageOverlayVLength; // UV height of a texture (for damageOverlays == true only)
	
	void effect() {
		vec2 textureCoords = VaryingTexCoord.st;
		vec4 surfaceTexel = Texel(surfaceMap, textureCoords);
		vec3 mapNormal = surfaceTexel.rgb;
		float ambientIllumination = surfaceTexel.a;
		vec4 diffuseTexel = Texel(diffuseMap, textureCoords);
		vec4 materialTexel = Texel(materialMap, textureCoords);
		
		if (damageOverlays) {
			vec2 damageCoords = vec2(textureCoords.s, mod(textureCoords.t, damageOverlayVLength) + damageOverlayVLength * damage);
			vec4 damageDiffuse = Texel(diffuseMap, damageCoords);
			vec4 damageSurface = Texel(surfaceMap, damageCoords);
			vec4 damageMaterial = Texel(materialMap, damageCoords); // Just *stored* in the material map.
			float damageNormalAlpha = damageMaterial.r;
			float damageAmbientIlluminationAlpha = damageMaterial.g;
			diffuseTexel.rgb = mix(diffuseTexel.rgb, damageDiffuse.rgb, damageDiffuse.a);
			mapNormal = mix(mapNormal, damageSurface.rgb, damageNormalAlpha);
			ambientIllumination = mix(ambientIllumination, damageSurface.a, damageAmbientIlluminationAlpha);
		}
		
		vec3 outNormal = perturbNormal(fragmentNormal, mapNormal * 2 - 1, textureCoords, normalize(viewPosition - fragmentPosition));
		
		love_Canvases[0] = vec4(fragmentPosition, 1);
		love_Canvases[1] = vec4(outNormal, ambientIllumination);
		love_Canvases[2] = diffuseTexel;
		love_Canvases[3] = materialTexel;
	}
#endif
