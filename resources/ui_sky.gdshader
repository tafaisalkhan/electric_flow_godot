shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.33, 0.68, 0.93, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.99, 0.995, 1.0, 1.0);

void fragment() {
    float blend = smoothstep(0.18, 0.88, UV.y);
    COLOR = mix(top_color, bottom_color, blend);
}
