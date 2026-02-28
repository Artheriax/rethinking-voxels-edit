#include "/lib/common.glsl"
    
layout(local_size_x = 64) in;

//layout(local_size_x = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef ACCURATE_RT
#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"

shared int totalCounts[pointerGridSize.x];

void main() {

        int thisTotalCount = 0;
        int x = int(gl_LocalInvocationID.x);
        for (int y = 0; y < pointerGridSize.y; y++) {
                for (int z = 0; z < pointerGridSize.z; z++) {
                        thisTotalCount += readVolumePointer(ivec3(x, y, z), 0) + 1;//pointerVolume[0][x][y][z] + 1;
                }
        }
        totalCounts[x] = thisTotalCount;
        
        // Ensure all shared memory writes are visible to other invocations
        memoryBarrierShared();
        barrier();
        
        if (x == 0) {
                for (int x0 = 1; x0 < pointerGridSize.x; x0++) {
                        totalCounts[x0] += totalCounts[x0-1];
                }
        }
        
        // Ensure prefix sum is complete before other threads read
        memoryBarrierShared();
        barrier();
        
        thisTotalCount = totalCounts[x] - thisTotalCount;
        for (int y = 0; y < pointerGridSize.y; y++) {
                for (int z = 0; z < pointerGridSize.z; z++) {
                        writeTriPointer(thisTotalCount, 1);//triPointerStrip[thisTotalCount] = 1;
                        writeVolumePointer(ivec3(x, y, z), 1, thisTotalCount);//pointerVolume[1][x][y][z] = thisTotalCount;
                        thisTotalCount += readVolumePointer(ivec3(x, y, z), 0) + 1;//pointerVolume[0][x][y][z] + 1;
                }
        }
}
#else
void main() {}
#endif