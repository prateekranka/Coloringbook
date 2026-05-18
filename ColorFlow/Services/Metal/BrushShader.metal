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
    float absPerp = abs(in.perpNorm);

    if (absPerp > 1.0) {
        discard_fragment();
    }

    float innerEdge = 1.0 - in.softness;
    float alpha = 1.0 - smoothstep(innerEdge, 1.0, absPerp);

    float2 fragPixel = in.position.xy;
    float noise = hash21(fragPixel * 0.25, in.seed);

    switch (in.brushKind) {
        case 0: {
            alpha *= mix(1.0, noise, in.noiseStrength * 0.5);
            alpha *= in.color.a * 0.9;
            break;
        }
        case 1: {
            alpha *= 0.95;
            alpha *= in.color.a;
            break;
        }
        case 2: {
            float noiseMod = mix(1.0, noise * 0.7 + 0.3, in.noiseStrength);
            alpha *= noiseMod * 0.85;
            alpha *= in.color.a * 0.65;
            break;
        }
        case 3: {
            float threshold = 0.3 + in.noiseStrength * 0.4;
            if (noise < threshold) {
                discard_fragment();
            }
            alpha *= mix(0.4, 1.0, noise) * in.color.a;
            break;
        }
        case 4: {
            alpha *= mix(1.0, noise, in.noiseStrength * 0.2);
            alpha *= in.color.a;
            break;
        }
        default:
            break;
    }

    if (alpha <= 0.003) {
        discard_fragment();
    }

    return float4(in.color.rgb * alpha, alpha);
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