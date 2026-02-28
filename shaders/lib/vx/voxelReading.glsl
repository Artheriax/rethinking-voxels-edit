#ifndef READING
#define READING

#include "/lib/vx/SSBOs.glsl"

struct vxData {
        vec3 lower;
        vec3 upper;
        vec3 midcoord;
        vec3 lightcol;
        ivec2 texelcoord;
        int spritesize;
        int mat;
        int lightlevel;
        int skylight;
        bool trace;
        bool full;
        bool cuboid;
        bool alphatest;
        bool emissive;
        bool crossmodel;
        bool connectsides;
        bool entity;
};

//read data from the voxel map (excluding flood fill data)
vxData readVxMap(ivec3 coords) {
        vxData data;
        #ifndef ACCURATE_RT
                uvec4 packedData = readVoxelVolume(coords, 1);
                if (packedData.x == 0) {
                #endif
                data.lightcol = vec3(0); // lightcol is gl_Color.rgb for anything that isn't a light source
                data.texelcoord = ivec2(-1);
                data.lower = vec3(0);
                data.upper = vec3(0);
                data.midcoord = vec3(0.5);
                data.mat = -1;
                data.full = false;
                data.cuboid = false;
                data.alphatest = false;
                data.trace = false;
                data.emissive = false;
                data.crossmodel = false;
                data.spritesize = 0;
                data.lightlevel = 0;
                data.skylight = 15;
                data.connectsides = false;
                data.entity=false;
                #ifndef ACCURATE_RT
                } else {
                        // Optimized: Use bitwise AND instead of modulo for faster unpacking
                        // packedData.z: RGB (24 bits) + blocktype (8 bits)
                        data.lightcol = vec3(
                                packedData.z & 255u,
                                (packedData.z >> 8) & 255u,
                                (packedData.z >> 16) & 255u
                        ) / 255.0;
                        // packedData.y: texelcoord (32 bits)
                        data.texelcoord = ivec2(
                                packedData.y & 65535u,
                                packedData.y >> 16
                        );
                        // packedData.x: mat (16 bits) + lightlevel (16 bits)
                        data.mat = int(packedData.x & 65535u);
                        data.lightlevel = int(packedData.x >> 16);
                        
                        // Block type flags (8 bits in packedData.z >> 24)
                        uint type = packedData.z >> 24;
                        data.alphatest = (type & 1u) != 0u;
                        data.crossmodel = (type & 2u) != 0u;
                        data.full = (type & 4u) != 0u;
                        data.emissive = (type & 8u) != 0u;
                        data.cuboid = (type & 16u) != 0u && !data.full;
                        data.trace = (type & 32u) == 0u;
                        data.connectsides = (type & 64u) != 0u;
                        data.entity = (type & 128u) != 0u;
                        
                        // packedData.w: bounds (24 bits) + spritelog (4 bits) + skylight (4 bits)
                        data.spritesize = 1 << ((packedData.w >> 24) & 15u);
                        data.skylight = int((packedData.w >> 28) & 15u);
                        
                        if (data.cuboid) {
                                data.lower = vec3(
                                        packedData.w & 15u,
                                        (packedData.w >> 4) & 15u,
                                        (packedData.w >> 8) & 15u
                                ) / 16.0;
                                data.upper = (vec3(
                                        (packedData.w >> 12) & 15u,
                                        (packedData.w >> 16) & 15u,
                                        (packedData.w >> 20) & 15u
                                ) + 1) / 16.0;
                        } else {
                                data.lower = vec3(0);
                                data.upper = vec3(1);
                        }
                        if (data.crossmodel || data.entity) {
                                data.midcoord = vec3(
                                        packedData.w & 255u,
                                        (packedData.w >> 8) & 255u,
                                        (packedData.w >> 16) & 255u
                                ) / 256.0;
                        } else {
                                data.midcoord = vec3(0.5);
                        }
                }
        #endif
        return data;
}

vxData readVxMap(vec3 vxPos) {
        ivec3 coord = ivec3(vxPos + pointerGridSize * POINTER_VOLUME_RES / 2);
        return readVxMap(coord);
}
#endif