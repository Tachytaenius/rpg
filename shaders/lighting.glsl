#define sq(x) (x)*(x)

const float pi = 3.14159265359;

float distribution(float roughness, float NdH) {
	float m = sq(roughness);
	float m2 = sq(m);
	float d = (NdH * m2 - NdH) * NdH + 1.0;
	return m2 / (pi * sq(d));
}

float geometry(float roughness, float NdV, float NdL) {
	float k = sq(roughness) / 2.0;
	float V = NdV * (1.0 - k) + k;
	float L = NdL * (1.0 - k) + k;
	return 0.25 / (V * L);
}

vec3 specular(float NdL, float NdV, float NdH, vec3 specularity, float roughness, float rimLighting) {
	float D = distribution(roughness, NdH);
	float G = geometry(roughness, NdV, NdL);
	float rim = mix(1.0 - roughness * rimLighting * 0.9, 1.0, NdV);
	return 1.0 / rim * specularity * G * D;
}

vec3 fresnel(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float attenuate(float strength, float dist) {
	return pow(max(1.0 - dist / strength, 0.0), 0.75);
}

uniform vec3 viewPosition;

uniform Image positionBuffer;
uniform Image surfaceBuffer;
uniform Image albedoBuffer;
uniform Image materialBuffer;

uniform bool pointLight; // or directional
uniform vec3 lightPosition; // angle for directionals
uniform vec3 lightColour;
uniform float nearPlane;
uniform float lightStrength; // also far plane
uniform Image shadowMap;
uniform mat4 lightView;
uniform float ambience;
uniform vec2 windowSize;
uniform float minimumBias;
uniform float maximumBias;
uniform bool temporary_enableShadows;

float depthToLinear(float depth, float near, float far) {
	float z = depth * 2.0 - 1.0;
	return (2.0 * near * far) / (far + near - z * (far - near));
}

vec4 effect(vec4 colour, Image image, vec2 textureCoords, vec2 windowCoords) {
	textureCoords = windowCoords / windowSize;
	
	vec4 positionTexel = Texel(positionBuffer, textureCoords);
	if (positionTexel.a == 0.0) discard;
	vec4 materialTexel = Texel(materialBuffer, textureCoords);
	vec4 surfaceTexel = Texel(surfaceBuffer, textureCoords);
	
	vec3 position = positionTexel.xyz;
	vec3 normal = surfaceTexel.xyz;
	vec3 albedo = Texel(albedoBuffer, textureCoords).rgb;
	
	float metalness = materialTexel.r;
	float roughness = materialTexel.g;
	float rimLighting = materialTexel.b;
	
	float ambientIllumination = surfaceTexel.a; // 1 - ambientOcclusion. I made full alpha be full illumination because then in graphics editors normals become irrelevant when occlusion goes up (alpha goes down), like in the actual renderer. Just my way of seeing things.
	
	vec3 L = pointLight?
		normalize(position - lightPosition):
		normalize(-lightPosition);
	vec3 V = normalize(position - viewPosition);
	vec3 H = normalize(L + V);
	
	bool lit = true;
	if(temporary_enableShadows) {
	float bias = max(maximumBias * (1.0 - dot(normal, L)), minimumBias);
	vec4 shadowCoords = lightView * positionTexel;
	vec2 shadowMapCoords = (shadowCoords.xy / shadowCoords.w) / 2.0 + 0.5;
	float shadowDistance = depthToLinear(Texel(shadowMap, shadowMapCoords).r, nearPlane, lightStrength);
	bool inShadowMap = clamp(shadowMapCoords, 0.0, 1.0) == shadowMapCoords && shadowCoords.z >= 0;
	lit = inShadowMap && shadowCoords.z - bias <= shadowDistance;
	}
	
	vec3 radiance = lit?
		pointLight?
			lightColour * attenuate(lightStrength, distance(position, lightPosition)):
			lightColour * lightStrength:
		vec3(0.0);
	
	vec3 specularity = mix(vec3(0.04), albedo, metalness);
	
	vec3 N = normal;
	float NdL = max(dot(N, L), 0.0);
	float NdV = max(dot(N, V), 0.0);
    float NdH = max(dot(N, H), 0.0);
    float HdV = clamp(dot(H, V), 0.0, 1.0);
    float LdV = max(dot(L, V), 0.0);
	
	vec3 specfresnel = fresnel(HdV, specularity);
	vec3 specref = specular(NdL, NdV, NdH, specfresnel, roughness, rimLighting);
	
	specref *= NdL;
	
	vec3 diffref = (1.0 - specfresnel) / pi * NdL;
	
	vec3 reflectedLight = specref * radiance;
	vec3 diffuseLight = diffref * radiance;
	
	vec3 result =
		diffuseLight * mix(albedo, vec3(0.0), metalness) +
		reflectedLight +
		(albedo * lightColour) * (ambientIllumination * ambience); // Brackets to help, they're not necessary
	
	return vec4(result, 1.0);
}
