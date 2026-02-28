int propagates(vxData blockData, inout vec3 colMult) {
        int propval;
        vec4 texCol = vec4(1);
        if (blockData.alphatest) {
                vec4 texCol0[3] = vec4[3](
                        texture2DLod(colortex15, blockData.texcoord, 0),
                        texture2DLod(colortex15, blockData.texcoord, 1),
                        texture2DLod(colortex15, blockData.texcoord, 3)
                );
                for (int i = 0; i < 3; i++) if (texCol0[i].a < texCol.a) texCol = texCol0[i];
        }
        if (blockData.emissive || !blockData.trace || blockData.crossmodel || texCol.a < 0.2) propval = 127;
        else if (texCol.a < 0.8) {
                propval = 127;
                texCol.a = pow(texCol.a, TRANSLUCENT_LIGHT_TINT);
                texCol.rgb /= max(max(0.0001, texCol.r), max(texCol.g, texCol.b));
                texCol.rgb *= 0.5 + TRANSLUCENT_LIGHT_CONDUCTION / max(0.0001, texCol.r + texCol.g + texCol.b);
                colMult = clamp(1 - texCol.a + texCol.a * texCol.rgb, vec3(0), vec3(max(1.0, TRANSLUCENT_LIGHT_CONDUCTION + 0.02)));
        }
        else if (blockData.full) propval = 0;
        else if (blockData.cuboid) {
                propval = 0;
                for (int k = 1; k < 7; k++) {
                        if ((blockData.lower[(k-1)%3] < 0.02 && k < 4) || (blockData.upper[(k-1)%3] > 0.98 && k >= 4)) {
                                bool seals = true;
                                for (int i = (k+3)%3; i != (k+2)%3; i = (i+1)%3) {
                                        if (blockData.lower[i] > 0.02 || blockData.upper[i] < 0.98) seals = false;
                                }
                                if (!seals) propval += 1<<(k-1);
                        } else propval += 1<<(k-1);
                }
        } else propval = 127;
        return propval;
}
int propagates(vxData blockData) {
        vec3 colMult;
        return propagates(blockData, colMult);
}