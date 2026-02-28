#include "/lib/common.glsl"

const ivec3 workGroups = ivec3(4, 2, 4);

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"

#define MAX_LOCAL_LIGHTS 64

void main() {
        int localLightCount = readVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 4);
        if (localLightCount == 0) return;
        
        // Optimized: Use single flat arrays instead of 2D bin arrays
        // This reduces memory usage and improves cache locality
        int pointers[MAX_LOCAL_LIGHTS];
        float scores[MAX_LOCAL_LIGHTS];
        int validCount = 0;
        
        vec3 midPos = ((gl_GlobalInvocationID.xyz + 0.5) * 4.0 - pointerGridSize / 2.0) * POINTER_VOLUME_RES + vec3(0.001, 0.002, -0.001);
        int lightStripLoc = readVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 5) + 1;
        
        // Collect and score all lights
        int maxLights = min(localLightCount, MAX_LOCAL_LIGHTS);
        for (int k = 0; k < maxLights; k++) {
                int thisPointer = readLightPointer(lightStripLoc + k);
                if (thisPointer < 0) continue; // Bounds safety
                light_t thisLight = lights[thisPointer];
                // Score = brightness - distance (higher is better)
                float score = (thisLight.brightnessMat >> 16) - length(midPos - thisLight.pos);
                
                // Skip lights with negative score (too far/dim)
                if (score < 0.0) continue;
                
                pointers[validCount] = thisPointer;
                scores[validCount] = score;
                validCount++;
        }
        
        // Insertion sort: efficient for small arrays, better cache locality than binning
        for (int i = 1; i < validCount; i++) {
                int tempPtr = pointers[i];
                float tempScore = scores[i];
                int j = i;
                // Shift elements to make room (sort descending by score)
                while (j > 0 && scores[j - 1] < tempScore) {
                        pointers[j] = pointers[j - 1];
                        scores[j] = scores[j - 1];
                        j--;
                }
                pointers[j] = tempPtr;
                scores[j] = tempScore;
        }
        
        // Write sorted lights (limit to 64)
        int writeCount = min(validCount, MAX_LOCAL_LIGHTS);
        for (int k = 0; k < writeCount; k++) {
                writeLightPointer(lightStripLoc + k, pointers[k]);
        }
        writeLightPointer(lightStripLoc - 1, writeCount + 1);
        writeVolumePointer(ivec3(gl_GlobalInvocationID.xyz), 4, writeCount);
}