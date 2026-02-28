#include "/lib/common.glsl"

const ivec3 workGroups = ivec3(64, 32, 64);

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#ifndef ACCURATE_RT

uniform int frameCounter;

#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"
#include "/lib/vx/voxelReading.glsl"

// Maximum local lights per workgroup to prevent stack overflow
#define MAX_LOCAL_LIGHTS 64

void main() {
        const vec3 defaultLightSize = 0.5 * vec3(BLOCKLIGHT_SOURCE_SIZE);
        const int intpointerVolumeRes = int(POINTER_VOLUME_RES + 0.001);
        const int maxLocalLights = min(intpointerVolumeRes * intpointerVolumeRes * intpointerVolumeRes, MAX_LOCAL_LIGHTS);
        
        int nLights = 0;
        light_t localLights[MAX_LOCAL_LIGHTS];
        vxData localVoxelData[MAX_LOCAL_LIGHTS];
        
        for (int x0 = 0; x0 < intpointerVolumeRes; x0++) {
                for (int y0 = 0; y0 < intpointerVolumeRes; y0++) {
                        for (int z0 = 0; z0 < intpointerVolumeRes; z0++) {
                                ivec3 blockCoord = intpointerVolumeRes * ivec3(gl_WorkGroupID) + ivec3(x0, y0, z0);
                                if (readVoxelVolume(blockCoord, 0).x == 0) {
                                        writeVoxelVolume(blockCoord, 1, uvec4(0));
                                        continue;
                                }
                                writeVoxelVolume(blockCoord, 0, uvec4(0));
                                vxData thisVoxelData = readVxMap(blockCoord);
                                if (thisVoxelData.emissive) {
                                        // Prevent local array overflow
                                        if (nLights >= maxLocalLights) continue;
                                        
                                        light_t thisLight;
                                        thisLight.pos = blockCoord - POINTER_VOLUME_RES * pointerGridSize / 2.0;
                                        if (thisVoxelData.cuboid) {
                                                thisLight.pos += 0.5 * (thisVoxelData.upper + thisVoxelData.lower);
                                                #ifdef CORRECT_CUBOID_OFFSETS
                                                        thisLight.size = 0.5 * (thisVoxelData.upper - thisVoxelData.lower);
                                                #else
                                                        thisLight.size = defaultLightSize;
                                                #endif
                                        } else {
                                                thisLight.pos += thisVoxelData.midcoord;
                                                #ifdef CORRECT_CUBOID_OFFSETS
                                                        thisLight.size = thisVoxelData.full ? vec3(0.5) : defaultLightSize;
                                                #else
                                                        thisLight.size = defaultLightSize;
                                                #endif
                                        }
                                        // Safe color clamping to prevent overflow
                                        vec3 safeColor = clamp(thisVoxelData.lightcol, vec3(0.0), vec3(1.0));
                                        thisLight.packedColor = int(safeColor.x * 255.9) + (int(safeColor.y * 255.9) << 8) + (int(safeColor.z * 255.9) << 16);
                                        thisLight.brightnessMat = thisVoxelData.mat + (thisVoxelData.lightlevel << 16);
                                        #ifdef CLUMP_LIGHTS
                                        bool alreadyHadThisOne = false;
                                        for (int k = 0; k < nLights; k++)
                                                if (localLights[k].brightnessMat == thisLight.brightnessMat) {
                                                        alreadyHadThisOne = true;
                                                        vec3 jointLower = min(localLights[k].pos - localLights[k].size, thisLight.pos - thisLight.size);
                                                        vec3 jointUpper = max(localLights[k].pos + localLights[k].size, thisLight.pos + thisLight.size);
                                                        localLights[k].pos = 0.5 * (jointLower + jointUpper);
                                                        localLights[k].size = 0.5 * (jointUpper - jointLower);
                                                        break;
                                                }
                                        if (alreadyHadThisOne) continue;
                                        #endif
                                        localVoxelData[nLights] = thisVoxelData;
                                        localLights[nLights++] = thisLight;
                                }
                        }
                }
        }
        for (int n = 0; n < nLights; n++) {
                // Check capacity BEFORE atomic add to prevent counter overflow
                int currentCount = numLights;
                if (currentCount >= MAX_LIGHTS) break;
                
                int globalLightId = atomicAdd(numLights, 1);
                if (globalLightId >= MAX_LIGHTS) break;
                
                lights[globalLightId] = localLights[n];
                ivec3 coords = ivec3(localLights[n].pos / POINTER_VOLUME_RES + pointerGridSize / 2) / 4;
                // Safe division with epsilon to prevent divide-by-zero
                int lightRange = max(1, localVoxelData[n].lightlevel / max(1, int(4.01 * POINTER_VOLUME_RES)));
                ivec3 lowerBound = max(coords - lightRange - 1, ivec3(0));
                ivec3 upperBound = min(coords + lightRange + 1, pointerGridSize / 4);
                for (int x = lowerBound.x; x <= upperBound.x; x++) {
                        for (int y = lowerBound.y; y <= upperBound.y; y++) {
                                for (int z = lowerBound.z; z <= upperBound.z; z++) {
                                        incrementVolumePointer(ivec3(x, y, z), 4);
                                }
                        }
                }
        }
}
#else
void main() {}
#endif