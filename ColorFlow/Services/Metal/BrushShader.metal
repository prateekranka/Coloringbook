#include <metal_stdlib>
using namespace metal;

struct StrokeVertex {
    float4 color;
    float2 position;
    float  halfWidth;
    float  softness;
    float  noiseStrength;
    float  seed;
    float  perpNorm;
};

struct StrokeUniforms {
    float2 viewportSize;
    int    brushKind;
    int    _pad0;
};

struct StrokeVertexOut {
    float4 position [[position]];
    float4 color;
    float  halfWidth;
    float  softness;
    float  noiseStrength;
    float  seed;
    float  perpNorm;
    int    brushKind;
};

struct BlitVertexOut {
    float4 position [[position]];
    float2 uv;
};

float hash21(float2 p, float s) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z + s);
}

vertex StrokeVertexOut brush_stroke_vertex(
    constant StrokeVertex *vertices [[buffer(0)]],
    constant StrokeUniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    StrokeVertexOut out;
    StrokeVertex v = vertices[vid];

    float2 pixelPos = v.position;

    out.position = float4(
        (pixelPos.x / uniforms.viewportSize.x) * 2.0 - 1.0,
        1.0 - (pixelPos.y / uniforms.viewportSize.y) * 2.0,
        0.0, 1.0
    );

    out.color         = v.color;
    out.halfWidth     = v.halfWidth;
    out.softness      = v.softness;
    out.noiseStrength = v.noiseStrength;
    out.seed          = v.seed;
    out.perpNorm      = v.perpNorm;
    out.brushKind     = uniforms.brushKind;

    return out;
}

fragment float4 brush_stroke_fragment(
    StrokeVertexOut in [[stage_in]]
) {
    float2 pos = in.position.xy;
    float  h   = in.halfWidth;

    float d = abs(in.perpNorm);

    float edge = 1.0 - smoothstep(0.85, 1.0, d);

    float n = hash21(pos, in.seed);
    n = mix(0.5, 1.0, n);
    float noiseFactor = 1.0 - (n - 0.5) * 2.0 * in.noiseStrength;
    edge *= noiseFactor;

    float4 color = in.color;
    color.a *= edge;

    if (in.brushKind == 1) {
        float pastelMix = 0.35;
        color.rgb = mix(color.rgb, float3(1.0), pastelMix);
        color.a *= 0.92;
    }

    return color;
}

vertex BlitVertexOut brush_blit_vertex(
    constant float2 *vertices [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    BlitVertexOut out;
    float2 pos = vertices[vid];
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment float4 brush_blit_fragment(
    BlitVertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return sourceTexture.sample(textureSampler, in.uv);
}
