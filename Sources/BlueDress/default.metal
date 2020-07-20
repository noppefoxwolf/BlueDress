#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;

vertex ImageColorInOut vertexShader(const device float4 *position [[ buffer(0) ]],
                               const device float2 *texCoords [[ buffer(1) ]],
                               uint    vid      [[ vertex_id ]]) {
  ImageColorInOut out;
  out.position = position[vid];
  out.texCoord = texCoords[vid];
  return out;
}

fragment float4 fragmentShader(ImageColorInOut in [[ stage_in ]],
                               texture2d<float, access::sample> capturedImageTextureY [[ texture(0) ]],
                               texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(1) ]]) {
  constexpr sampler colorSampler(mip_filter::linear,
                                 mag_filter::linear,
                                 min_filter::linear);
  const float4x4 ycbcrToRGBTransform = float4x4(
      float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
      float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
      float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
      float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
  );
  
  // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
  float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                        capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg,
                        1.0);
  
  // Return converted RGB color
  return ycbcrToRGBTransform * ycbcr;
}
