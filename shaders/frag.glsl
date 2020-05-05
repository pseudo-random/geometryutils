#version 450 core

in vec4 p_color;
in vec3 p_normal;

out vec4 color;

uniform vec4 u_color[128];
uniform vec3 u_light_dir;

void main() {
  float intensity = clamp(dot(normalize(p_normal), normalize(u_light_dir)), 0, 1);
  color = p_color * intensity * 0.8 + 0.2 * p_color;
}
