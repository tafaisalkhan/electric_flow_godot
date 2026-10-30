shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.972, 0.987, 1.0, 1.0);
uniform vec4 cloud_blue : source_color = vec4(0.69, 0.85, 0.97, 1.0);

void fragment() {
    vec2 p = UV;
    float cloud_a = exp(-dot((p - vec2(0.73, 0.11)) * vec2(1.8, 1.0), (p - vec2(0.73, 0.11)) * vec2(1.8, 1.0)) * 7.0);
    float cloud_b = exp(-dot((p - vec2(0.09, 0.54)) * vec2(1.6, 1.2), (p - vec2(0.09, 0.54)) * vec2(1.6, 1.2)) * 8.0);
    float cloud_c = exp(-dot((p - vec2(0.92, 0.65)) * vec2(1.6, 1.2), (p - vec2(0.92, 0.65)) * vec2(1.6, 1.2)) * 9.0);
    COLOR = mix(paper, cloud_blue, clamp(cloud_a * 0.67 + cloud_b * 0.35 + cloud_c * 0.3, 0.0, 1.0));
}
