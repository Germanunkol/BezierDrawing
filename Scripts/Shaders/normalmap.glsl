//Normalmap shader for Löve:

uniform vec3 LightPos;
uniform sampler2D nm;
uniform sampler2D sm;


uniform vec2 Resolution = vec2(500,300);      //resolution of screen
vec4 LightColor = vec4(1.0, 0.8, 0.6, 0.5);      //light RGBA -- alpha is intensity
uniform vec4 AmbientColor = vec4(1.0, 1.0, 1.0, 0.5);    //ambient RGBA -- alpha is intensity 
//vec3 Falloff = vec3(0.4,3,20);         //attenuation coefficients
vec3 Falloff = vec3(0.8,1.0,6.0);         //attenuation coefficients
vec3 SunDir = vec3(0.0,0.0,1.0);

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
/*
	N = normalize(Normal.xyz)
L = normalize(LightDir.xyz)

Diffuse = LightColor * max(dot(N, L), 0.0)

Ambient = AmbientColor * AmbientIntensity

Attenuation = 1.0 / (ConstantAtt + (LinearAtt * Distance) + (QuadraticAtt * Distance * Distance)) 

Intensity = Ambient + Diffuse * Attenuation

FinalColor = DiffuseColor.rgb * Intensity.rgb*/

	//RGBA of our diffuse color
	vec4 DiffuseColor = texture2D(texture, texture_coords);
	
	//RGB of our normal map
	vec3 NormalMap = texture2D(nm, texture_coords).rgb;
	
	//RGB of our spec map
	vec3 SpecularMap = texture2D(sm, texture_coords).rgb;
	
	//The delta position of light
	vec3 LightDir = vec3((LightPos.xy - pixel_coords.xy)/Resolution.xy, LightPos.z);
	
	//Correct for aspect ratio
	LightDir.x *= Resolution.x / Resolution.y;
	
	//Determine distance (used for attenuation) BEFORE we normalize our LightDir
	float D = length(LightDir);
	
	//normalize our vectors
	vec3 N = normalize(NormalMap * 2.0 - 1.0);
	vec3 L = normalize(LightDir);
	
	//Pre-multiply light color with intensity
	//Then perform "N dot L" to determine our diffuse term
	vec3 Diffuse = (LightColor.rgb * SpecularMap.rgb * LightColor.a) * max(dot(N, L), 0.0);

	//pre-multiply ambient color with intensity
	vec3 Ambient = AmbientColor.rgb * AmbientColor.a * N.z;
	
	//calculate attenuation
	float Attenuation = 1.0 / ( Falloff.x + (Falloff.y*D) + (Falloff.z*D*D) );
	
	//the calculation which brings it all together
	vec3 Intensity = Ambient + Diffuse * Attenuation;
	vec3 FinalColor = DiffuseColor.rgb * Intensity;
	gl_FragColor = color * vec4(FinalColor, DiffuseColor.a);
	return gl_FragColor;
}
