const float gamma = 2.2;

// uniform float colourLevels = 16;
uniform Image positionBuffer;
uniform vec3 skyColour;
uniform vec3 viewPosition;
uniform float fogRadius;
uniform float fogStart;

vec4 effect(vec4 colour, Image image, vec2 textureCoords, vec2 windowCoords) {
	vec4 positionTexel = Texel(positionBuffer, textureCoords);
	if (positionTexel.a == 0.0) return vec4(skyColour, 1.0);
	vec3 position = positionTexel.xyz;
	
	vec3 fragmentColour = Texel(image, textureCoords).rgb;
	float dist = distance(position, viewPosition);
	float mixFactor = (dist - fogStart * fogRadius) / ((1.0 - fogStart) * fogRadius);
	mixFactor = clamp(mixFactor, 0.0, 1.0);
	fragmentColour = mix(fragmentColour, skyColour, mixFactor);
	// fragmentColour = floor(fragmentColour * (colourLevels - 1)) / (colourLevels - 1);
	return vec4(fragmentColour, 1.0);
}
 