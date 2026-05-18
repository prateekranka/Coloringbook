#include <metal_stdlib>
using namespace metal;

// MARK: - Brush Shader

struct BrushVertex {
    float2 position;
    float2 center;
    float  pointSize;
    float4 color;
    float  softness;
};

struct BrushVertexOut {
    float4 position [[position]];
    float  pointSize;
    float4 color;
    float  softness;
    float2 center;
    float2 fragPos;
};

struct BrushUniforms {
    float2 viewportSize;
};

vertex BrushVertexOut brush_vertex(
    constant BrushVertex *vertices [[buffer(0)]],
    constant BrushUniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    BrushVertexOut out;
    float2 pixelPos = vertices[vid].position;

    out.position.x = (pixelPos.x / uniforms.viewportSize.x) * 2.0 - 1.0;
    out.position.y = 1.0 - (pixelPos.y / uniforms.viewportSize.y) * 2.0;
    out.position.z = 0.0;
    out.position.w = 1.0;

    out.pointSize = vertices[vid].pointSize;
    out.color     = vertices[vid].color;
    out.softness  = vertices[vid].softness;
    out.center    = vertices[vid].center;
    out.fragPos   = pixelPos;

    return out;
}

fragment float4 brush_fragment(
    BrushVertexOut in [[stage_in]]
) {
    float dist   = length(in.fragPos - in.center);
    float radius = in.pointSize * 0.5;

    float innerRadius = radius * (1.0 - in.softness);
    float circleAlpha = 1.0 - smoothstep(innerRadius, radius, dist);

    if (circleAlpha <= 0.001) {
        discard_fragment();
    }

    float4 premultiplied = float4(in.color.rgb * circleAlpha, circleAlpha) * in.color.a;
    return premultiplied;
}

// MARK: - Blit Shader (accumulation -> drawable)

struct BlitVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct BlitUniforms {
    float2 viewportSize;
};

vertex BlitVertexOut blit_vertex(
    constant float2 *vertices [[buffer(0)]],
    constant BlitUniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    BlitVertexOut out;
    float2 pos = vertices[vid];
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment float4 blit_fragment(
    BlitVertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return sourceTexture.sample(textureSampler, in.uv);
}
