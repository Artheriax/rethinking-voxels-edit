#ifndef IRRADIANCECACHE
#define IRRADIANCECACHE

// Optimized: Inline bounds check for better performance
bool isInRange(vec3 vxPos) {
    vec3 halfVolume = 0.5 * vec3(voxelVolumeSize);
    return all(greaterThan(vxPos, -halfVolume)) && all(lessThan(vxPos, halfVolume));
}

uniform sampler3D irradianceCache;

// Helper: Safe division with epsilon protection
vec3 safeDivide(vec3 numerator, float denominator) {
    float safeDenom = max(denominator, 0.0001);
    vec3 result = numerator / safeDenom;
    // NaN/Inf protection
    if (any(isnan(result)) || any(isinf(result))) {
        return vec3(0);
    }
    return result;
}

vec3 readIrradianceCache(vec3 vxPos, vec3 normal) {
    // Early exit for out-of-range positions
    if (!isInRange(vxPos)) return vec3(0);
    
    // Optimized: Combined coordinate calculation
    vec3 samplePos = ((vxPos + 0.5 * normal) / voxelVolumeSize + 0.5) * vec3(1.0, 0.5, 1.0);
    vec4 color = textureLod(irradianceCache, samplePos, 0);
    return safeDivide(color.rgb, color.a);
}

vec3 readSurfaceVoxelBlocklight(vec3 vxPos, vec3 normal) {
    // Early exit for out-of-range positions
    if (!isInRange(vxPos)) return vec3(0);
    
    // Optimized: Combined coordinate calculation with Y offset for surface reading
    vec3 samplePos = ((vxPos + 0.5 * normal) / voxelVolumeSize + vec3(0.5, 1.5, 0.5)) * vec3(1.0, 0.5, 1.0);
    vec4 color = textureLod(irradianceCache, samplePos, 0);
    
    // Optimized: Only apply tone mapping if there's significant light
    float lColor = length(color.rgb);
    if (lColor > 0.01) {
        color.rgb *= log(lColor + 1.0) / lColor;
    }
    
    // NaN/Inf protection
    if (any(isnan(color.rgb)) || any(isinf(color.rgb))) {
        return vec3(0);
    }
    return color.rgb;
}

vec3 readVolumetricBlocklight(vec3 vxPos) {
    // Early exit for out-of-range positions
    if (!isInRange(vxPos)) return vec3(0);
    
    // Optimized: Direct coordinate calculation for volumetric reading
    vec3 samplePos = (vxPos / voxelVolumeSize + vec3(0.5, 1.5, 0.5)) * vec3(1.0, 0.5, 1.0);
    vec4 color = textureLod(irradianceCache, samplePos, 0);
    return safeDivide(color.rgb, color.a);
}
#endif