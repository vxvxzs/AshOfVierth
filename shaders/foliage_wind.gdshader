shader_type canvas_item;

uniform float wind_strength : hint_range(0.0, 4.0, 0.1) = 1.15;
uniform float wind_speed : hint_range(0.0, 5.0, 0.1) = 1.15;
uniform float gust_strength : hint_range(0.0, 2.0, 0.05) = 0.35;
uniform float anchored_portion : hint_range(0.0, 0.9, 0.05) = 0.28;

void vertex() {
	// The trunk/base remains fixed while the upper foliage receives two
	// low-amplitude waves. World position desynchronises neighbouring plants.
	float free_height = smoothstep(anchored_portion, 1.0, 1.0 - UV.y);
	float phase = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].y * 0.009;
	float breeze = sin(TIME * wind_speed + phase);
	float gust = sin(TIME * wind_speed * 0.37 + phase * 1.7) * gust_strength;
	VERTEX.x += (breeze + gust) * wind_strength * free_height;
}
