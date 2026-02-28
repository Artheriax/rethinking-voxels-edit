#include "/lib/common.glsl"

in vec2[3] texCoordV;
in vec2[3] lmCoordV;
in vec4[3] vertexColV;
in vec3[3] posV;
in vec3[3] normalV;
in vec3[3] blockCenterOffsetV;
flat in vec3[3] sunVecV;
flat in vec3[3] upVecV;
flat in int[3] vertexID;
flat in int[3] spriteSizeV;
flat in int[3] matV;

flat out int mat;

out vec2 texCoord;

flat out vec3 sunVec, upVec;

out vec4 position;
flat out vec4 glColor;

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

uniform int frameCounter;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform ivec2 atlasSize;
uniform sampler2D gtexture;

//SSBOs//
#define WRITE_TO_SSBOS
#include "/lib/vx/SSBOs.glsl"

#include "/lib/materials/shadowchecks_precise.glsl"
#include "/lib/vx/voxelMapping.glsl"

// Optimized sampling offsets for emissive light color detection
// 4 corner samples at 0.2 offset from center (reduced from 9 random samples)
vec2[4] emissiveOffsets = vec2[4](
    vec2(-0.2, -0.2), vec2(0.2, -0.2), vec2(-0.2, 0.2), vec2(0.2, 0.2)
);

void main() 
{
        vec3 avgPos = 0.5 * (max(max(posV[0], posV[1]), posV[2]) + min(min(posV[0], posV[1]), posV[2]));
        vec3 cnormal = cross(posV[0] - posV[1], posV[0] - posV[2]);
        float area = length(cnormal);
        cnormal /= max(area, 0.000000001);
        avgPos += 8.0 * fract(0.125 * cameraPosition);
        vec3 avgPos0 = avgPos;
        avgPos += 0.01 * (
            blockCenterOffsetV[0]
          + blockCenterOffsetV[1]
          + blockCenterOffsetV[2]
        );
        bool tracemat = true;
        int mat0 = matV[0];

        bool doCuboidTexCoordCorrection = (mat0 / 10000 == 3);
        float zpos = 0.5 - clamp(sqrt(area), 0, 1) - 0.02 * fract(avgPos.y - 0.01 * cnormal.x) - 0.01 * fract(avgPos.x - 0.01 * cnormal.y) - 0.015 * fract(avgPos.z - 0.01 * cnormal.z) - 0.2 * cnormal.y;
        vec2 coord;
        adjustMat(mat0, cnormal, avgPos, area);
        if (getVoxelise(mat0, cnormal, area, posV)) {
                float normalOffset = getNormalOffset(mat0, area);
                avgPos -= normalOffset;
                if (doFullPosOffset(mat0)) avgPos0 -= normalOffset;
                adjustZpos(zpos, mat0, avgPos, cnormal);
        #ifdef ACCURATE_RT
                }
        #endif

        vec3 avgCenterOffset = 0.5 * (
                min(min(
                        blockCenterOffsetV[0],
                        blockCenterOffsetV[1]),
                        blockCenterOffsetV[2]
                ) + 
                max(max(
                        blockCenterOffsetV[0],
                        blockCenterOffsetV[1]),
                        blockCenterOffsetV[2]
                )
        );
        vec3 originBlock0 = avgPos + pointerGridSize * POINTER_VOLUME_RES / 2.0 + avgCenterOffset;
        vec3 pointerGridPos = originBlock0 / POINTER_VOLUME_RES;
        if (all(greaterThan(pointerGridPos, vec3(0))) && all(lessThan(pointerGridPos, pointerGridSize))) {
                ivec3 pointerGridCoords = ivec3(pointerGridPos);
                ivec3 originBlock = ivec3(originBlock0);
                int i0 = 0;
                float minSkew = 1;
                for (int i = 0; i < 3; i++) {
                        float thisSkew = abs(dot(
                                normalize(posV[(i+1)%3] - posV[i]),
                                normalize(posV[(i+2)%3] - posV[i])
                        ));
                        if (thisSkew < minSkew) {
                                minSkew = thisSkew;
                                i0 = i;
                        }
                }
                #ifdef ACCURATE_RT
                        int faceNum = atomicAdd(numFaces, 1);
                        if (faceNum < MAX_TRIS) {
                                incrementVolumePointer(pointerGridCoords, 0);//atomicAdd(pointerVolume[0][pointerGridCoords.x][pointerGridCoords.y][pointerGridCoords.z], 1);
                                int bools = ((mat0 / 10000 >= 5) ? 1 : 0);
                                tris[faceNum].matBools = mat0 + (bools << 16);
                                tris[faceNum].bvhParent =
                                        originBlock.x +
                                        512 * originBlock.y +
                                        262144 * originBlock.z;
                                for (int i = 0; i < 3; i++) {
                                        int j = (i + i0) % 3;
                                        uvec2 pixelCoord = uvec2(texCoordV[j] * atlasSize);
                                        uint packedVertexCol = uint(255 * vertexColV[j].r + 0.5) +
                                                                                        (uint(255 * vertexColV[j].g + 0.5) <<  8) +
                                                                                        (uint(255 * vertexColV[j].b + 0.5) << 16) +
                                                                                        (uint(255.5) << 24);
                                        tris[faceNum].vertexCol[i] = packedVertexCol;
                                        tris[faceNum].texCoord[i] = pixelCoord.x + 65536 * pixelCoord.y;
                                        tris[faceNum].pos[i] = posV[j] + 8 * fract(0.125 * cameraPosition) + 0.001 * blockCenterOffsetV[j];
                                }
                        }
                #else
                        uint zpos2 = uint(100000 * (2 - zpos));

                        if (maxVoxelVolume(originBlock, 0, 0, zpos2) < zpos2) {
                                vec2 outTexCoord = 0.5 * (max(max(texCoordV[0], texCoordV[1]), texCoordV[2]) + min(min(texCoordV[0], texCoordV[1]), texCoordV[2]));

                                if (max(max(abs(cnormal.x), abs(cnormal.y)), abs(cnormal.z)) > 0.9 && doCuboidTexCoordCorrection) {
                                        int l;
                                        for (l = 0; l < 3 && abs(cnormal[l]) < 0.5; l++);
                                        l = (l + 1) % 3;
                                        int k = (l + 1) % 3;
                                        vec3[3] blockRelVertPos0 = vec3[3](
                                                posV[0] + 8 * fract(0.125 * cameraPosition) - floor(avgPos) - 0.5,
                                                posV[1] + 8 * fract(0.125 * cameraPosition) - floor(avgPos) - 0.5,
                                                posV[2] + 8 * fract(0.125 * cameraPosition) - floor(avgPos) - 0.5);
                                        vec2[3] rPos = vec2[3](
                                                vec2(blockRelVertPos0[0][l], blockRelVertPos0[0][k]),
                                                vec2(blockRelVertPos0[1][l], blockRelVertPos0[1][k]),
                                                vec2(blockRelVertPos0[2][l], blockRelVertPos0[2][k]));
                                        vec2 dTexCoorddl = vec2(0);
                                        vec2 dTexCoorddk = vec2(0);
                                        for (int i = 0; i < 3; i++) {
                                                vec2 dPos = rPos[(i + 1) % 3] - rPos[i];
                                                if (abs(dPos[0]) > 10 * abs(dPos[1])) dTexCoorddl = (texCoordV[(i + 1) % 3] - texCoordV[i]) / dPos[0];
                                                if (abs(dPos[1]) > 10 * abs(dPos[0])) dTexCoorddk = (texCoordV[(i + 1) % 3] - texCoordV[i]) / dPos[1];
                                        }

                                        vec3 avgRelPos = avgPos - floor(avgPos) - 0.5;
                                        outTexCoord -= dTexCoorddl * avgRelPos[l] + dTexCoorddk * avgRelPos[k];
                                }
                                uvec4 dataToWrite = uvec4(0);
                                bool notrace = getNoTrace(mat0);
                                bool emissive = getEmissive(mat0);
                                bool entity = getEntity(mat0);
                                bool alphatest = false;
                                bool crossmodel = false;
                                bool cuboid = false;
                                bool full = false;
                                bool connectSides = false;
                                ivec3[2] bounds = ivec3[2](ivec3(0), ivec3(15));
                                if (!notrace) {
                                        alphatest = getAlphaTest(mat0);
                                        crossmodel = getCrossModel(mat0);
                                        full = getFull(mat0);
                                        cuboid = getCuboid(mat0);
                                        if (cuboid) {
                                                connectSides = getConnectSides(mat0);
                                                bounds = getBounds(mat0, avgPos0);
                                                bounds[1] -= ivec3(1);
                                        }
                                }
                                if (!cuboid || bounds[1].y == 15 || cnormal.y > 0.5) {
                                        int lightlevel = 0;
                                        vec3 lightCol = vec3(0);
                                        vec3 avgVertexCol = 0.33 * (
                                                vertexColV[0].rgb +
                                                vertexColV[1].rgb +
                                                vertexColV[2].rgb
                                        );
                                        if (emissive) {
                                                lightlevel = getLightLevel(mat0);
                                                lightCol = getLightCol(mat0);
                                                if (lightCol == vec3(0)) {
                                                        // Optimized: Single-pass selection with 5 samples (center + 4 corners)
                                                        // instead of 10 samples with two-pass algorithm
                                                        vec4 lightcol0 = texture(gtexture, outTexCoord) * vec4(avgVertexCol, 1);
                                                        lightcol0.rgb *= lightcol0.a;
                                                        float maxbrightness = max(max(lightcol0.x, lightcol0.y), lightcol0.z);
                                                        float bestScore = maxbrightness; // Use brightness as primary score
                                                        
                                                        for (int i = 0; i < 4; i++) {
                                                                vec4 sampleCol = texture(gtexture, outTexCoord + emissiveOffsets[i] * spriteSizeV[0] / atlasSize) * vec4(avgVertexCol, 1);
                                                                sampleCol.rgb *= sampleCol.a;
                                                                float thisbrightness = max(max(sampleCol.x, sampleCol.y), sampleCol.z);
                                                                // Select brightest sample (simpler than saturation-weighted selection)
                                                                if (thisbrightness > bestScore) {
                                                                        bestScore = thisbrightness;
                                                                        lightcol0 = sampleCol;
                                                                }
                                                                maxbrightness = max(maxbrightness, thisbrightness);
                                                        }
                                                        // Normalize and apply max brightness for consistent lighting
                                                        lightCol = lightcol0.rgb / max(max(lightcol0.r, max(lightcol0.g, lightcol0.b)), 0.0001) * maxbrightness;
                                                }
                                        } else lightCol = avgVertexCol;
                                        lightCol = clamp(lightCol, vec3(0), vec3(1));
                                        uint blocktype = 
                                                (alphatest ? 1 : 0) +
                                                (crossmodel ? 2 : 0) +
                                                (full ? 4 : 0) +
                                                (emissive ? 8 : 0) +
                                                (cuboid ? 16 : 0) +
                                                (notrace ? 32 : 0) +
                                                (connectSides ? 64 : 0) +
                                                (entity ? 128 : 0);
                                        uint lmCoord = uint(5.333 * clamp(lmCoordV[0] + lmCoordV[1] + lmCoordV[2], vec2(0), vec2(3)));

                                        uint spritelog = 0;
                                        while (spriteSizeV[0] >> spritelog + 1 != 0 && spritelog < 15) spritelog++;

                                        uvec2 midTexelCoord = uvec2(atlasSize * outTexCoord);
                                        dataToWrite.x = mat0 + (lightlevel << 16);
                                        dataToWrite.y = midTexelCoord.x + (midTexelCoord.y << 16);
                                        dataToWrite.z =
                                                uint(lightCol.r * 255.9) +
                                                (uint(lightCol.g * 255.9) << 8) +
                                                (uint(lightCol.b * 255.9) << 16) +
                                                (blocktype << 24);
                                        if (cuboid) dataToWrite.w = uint(
                                                bounds[0].x +
                                                (bounds[0].y << 4) +
                                                (bounds[0].z << 8) +
                                                (bounds[1].x << 12) +
                                                (bounds[1].y << 16) +
                                                (bounds[1].z << 20)
                                        );
                                        if (entity || crossmodel) {
                                                dataToWrite.w = uint(256 * fract(avgPos0.x)) + (uint(256 * fract(avgPos0.y)) << 8) + (uint(256 * fract(avgPos0.z)) << 16);
                                        }
                                        dataToWrite.w += (spritelog << 24) + (lmCoord << 28);
                                        writeVoxelVolume(originBlock, 1, dataToWrite);
                                }
                        }
                #endif
        }

        #ifndef ACCURATE_RT
                }
        #endif

        for (int i = 0; i < 3; i++) {
                gl_Position = gl_in[i].gl_Position;
                mat = matV[i];
                texCoord = texCoordV[i];
                sunVec = sunVecV[i];
                upVec = upVecV[i];
                position = vec4(posV[i], 1.0);
                glColor = vertexColV[i];
                EmitVertex();
        }
        EndPrimitive();
}