#include "/lib/common.glsl"

const ivec3 workGroups = ivec3(4, 2, 4);

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"

#define BIN_COUNT 16

void main() {
        int localLightCount = readVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 4);
        if (localLightCount > 0) {
                int pointers[BIN_COUNT][64];
                float scores[BIN_COUNT][64];
                int nums[BIN_COUNT];
                for (int k = 0; k < BIN_COUNT; k++) nums[k] = 0;
                vec3 midPos = ((gl_GlobalInvocationID.xyz + 0.5) * 4.0 - pointerGridSize / 2.0) * POINTER_VOLUME_RES + vec3(0.001, 0.002, -0.001);
                int lightStripLoc = readVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 5) + 1;
                for (int k = 0; k < localLightCount; k++) {
                        int thisPointer = readLightPointer(lightStripLoc + k);
                        light_t thisLight = lights[thisPointer];
                        float score0 = ((thisLight.brightnessMat >> 16) - length(midPos - thisLight.pos)) * BIN_COUNT / 26.0;
                        int score = min(int(score0), BIN_COUNT - 1);
                        int l = 0;
                        if (score < 0) continue;
                        // FIX: Use position-based tiebreaker for deterministic sorting
                        // Encodes position into a unique value that's consistent between frames
                        // This ensures stable ordering regardless of light discovery order
                        float tiebreaker = thisLight.pos.x + thisLight.pos.y * 128.0 + thisLight.pos.z * 16384.0;
                        float adjustedScore = score0 + tiebreaker * 0.0000001;
                        for (;
                                l < min(nums[score], 64) && scores[score][l] >= adjustedScore;
                                l++
                        );
                        if (l < 64) {
                                for (int j = min(nums[score], 63); j > l; j--) {
                                        scores[score][j] = scores[score][j-1];
                                        pointers[score][j] = pointers[score][j-1];
                                }
                                pointers[score][l] = thisPointer;
                                scores[score][l] = adjustedScore;
                                if (nums[score] < 64) nums[score]++;
                        }
                }
                int n = BIN_COUNT - 1;
                for (; n >= 0 && nums[n] <= 0; n--);
                int k;
                for (k = 0; k < min(localLightCount, 64) && n >= 0; k++) {
                        writeLightPointer(lightStripLoc + k, pointers[n][--nums[n]]);
                        for (; n >= 0 && nums[n] <= 0; n--);
                }
                writeLightPointer(lightStripLoc - 1, k + 1);
                writeVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 4, k);
        }
}