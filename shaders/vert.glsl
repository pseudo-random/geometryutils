#version 450 core

in vec3 pos;
in vec3 normal;

out vec3 p_normal;
out vec4 p_color;

uniform mat4 u_camera_mat;
uniform mat4 u_model_mat[128];
uniform vec4 u_color[128];

void main() {
  p_color = u_color[gl_InstanceID];
  p_normal = (u_model_mat[gl_InstanceID] * vec4(normal, 0)).xyz;
  gl_Position = u_camera_mat * u_model_mat[gl_InstanceID] * vec4(pos, 1);
}
