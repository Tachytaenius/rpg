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

vec3 attenuate(vec3 colour, float dist) {
	return 1.0 - smoothstep(vec3(0.0), colour, vec3(dist));
}

uniform vec3 viewPosition;

uniform Image positionBuffer;
uniform Image normalBuffer;
uniform Image albedoBuffer;
uniform Image materialBuffer;

uniform vec3 lightPosition;
uniform vec3 lightColour;

uniform vec3 skyColour;
uniform float ambience;

vec4 effect(vec4 colour, Image image, vec2 textureCoords, vec2 windowCoords) {
	vec4 positionTexel = Texel(positionBuffer, textureCoords);
	if (positionTexel.a == 0.0) return vec4(skyColour, 1);
	vec4 materialTexel = Texel(materialBuffer, textureCoords);
	vec4 normalTexel = Texel(normalBuffer, textureCoords);
	
	vec3 position = positionTexel.xyz;
	vec3 normal = normalTexel.xyz;
	vec3 albedo = Texel(albedoBuffer, textureCoords).rgb;
	
	float metalness = materialTexel.r;
	float roughness = materialTexel.g;
	float rimLighting = materialTexel.b;
	
	float ambientIllumination = normalTexel.a; // 1 - ambientOcclusion. I made full alpha be full illumination because then in graphics editors normals become irrelevant when occlusion goes up (alpha goes down), like in the actual program. Just my way of seeing things.
	
	vec3 radiance = attenuate(lightColour, length(position - lightPosition));
	
	vec3 L = normalize(position - lightPosition);
	vec3 V = normalize(position - viewPosition);
	vec3 H = normalize(L + V);
	
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
		albedo * (normalize(lightColour) * ambientIllumination * ambience);
	
	return vec4(result, 1.0);
}
