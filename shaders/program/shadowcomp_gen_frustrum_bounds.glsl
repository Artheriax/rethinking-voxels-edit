#include "/lib/common.glsl"

const ivec3 workGroups = ivec3(1, 1, 1);

layout (local_size_x = 4) in;

#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

vec2 corners[4] = vec2[4](
        vec2( 1, 1),
        vec2(-1, 1),
        vec2(-1,-1),
        vec2( 1,-1)
);
shared vec4 playerPos[4];
void main() {
        vec4 clipPos = vec4(corners[gl_LocalInvocationID.x], 0.999, 1);
        playerPos[gl_LocalInvocationID.x] = gbufferModelViewInverse * (gbufferProjectionInverse * clipPos);
        playerPos[gl_LocalInvocationID.x] /= playerPos[gl_LocalInvocationID.x].w;
        barrier();
        groupMemoryBarrier();
        frustrumSideNormals[gl_LocalInvocationID.x] = normalize(cross(playerPos[gl_LocalInvocationID.x].xyz, playerPos[(gl_LocalInvocationID.x + 1) % 4].xyz));
}