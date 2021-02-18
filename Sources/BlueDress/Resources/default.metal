#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;

vertex ImageColorInOut vertexShader(uint vid [[ vertex_id ]]) {
  const ImageColorInOut vertices[4] = {
    { float4(-1.0f, -1.0f, 0.0f, 1.0f), float2(0.0f, 1.0f) },
    { float4(1.0f, -1.0f, 0.0f, 1.0f), float2(1.0f, 1.0f) },
    { float4(-1.0f, 1.0f, 0.0f, 1.0f), float2(0.0f, 0.0f) },
    { float4(1.0f, 1.0f, 0.0f, 1.0f), float2(1.0f, 0.0f) },
  };
  return vertices[vid];
}

static inline
float4 BT709_decode(const float Y, const float Cb, const float Cr) {
    // Y already normalized to range [0 255]
    //
    // Note that the matrix multiply will adjust
    // this byte normalized range to account for
    // the limited range [16 235]
    //
    // Note that while a half float can be read from
    // the input textures, the values need to be full float
    // from this point forward since the bias values
    // need to be precise to avoid togggling blue and green
    // values depending on rounding.
    
    float Yn = (Y - (16.0f/255.0f));
    
    // Normalize Cb and CR with zero at 128 and range [0 255]
    // Note that matrix will adjust to limited range [16 240]
    
    float Cbn = (Cb - (128.0f/255.0f));
    float Crn = (Cr - (128.0f/255.0f));
    
    // Zero out the UV colors
    //Cbn = 0.0h;
    //Crn = 0.0h;
    
    // Represent half values as full precision float
    float3 YCbCr = float3(Yn, Cbn, Crn);
    
    // BT.709 (HDTV)
    // (col0) (col1) (col2)
    //
    // 1.1644  0.0000  1.7927
    // 1.1644 -0.2132 -0.5329
    // 1.1644  2.1124  0.0000
    
    // precise to 4 decimal places
    
    const float3x3 kColorConversion709 = float3x3(
                                                  // column 0
                                                  float3(1.1644f, 1.1644f, 1.1644f),
                                                  // column 1
                                                  float3(0.0f, -0.2132f, 2.1124f),
                                                  // column 2
                                                  float3(1.7927f, -0.5329f, 0.0f));
    
    // matrix to vector mult
    float3 rgb = kColorConversion709 * YCbCr;
    
    //  float Rn = (Yn * BT709Mat[0]) + (Cbn * BT709Mat[1]) + (Crn * BT709Mat[2]);
    //  float Gn = (Yn * BT709Mat[3]) + (Cbn * BT709Mat[4]) + (Crn * BT709Mat[5]);
    //  float Bn = (Yn * BT709Mat[6]) + (Cbn * BT709Mat[7]) + (Crn * BT709Mat[8]);
    
    //  float3 rgb;
    //  rgb.r = (YCbCr[0] * kColorConversion709[0][0]) + (YCbCr[1] * kColorConversion709[1][0]) + (YCbCr[2] * kColorConversion709[2][0]);
    //  rgb.g = (YCbCr[0] * kColorConversion709[0][1]) + (YCbCr[1] * kColorConversion709[1][1]) + (YCbCr[2] * kColorConversion709[2][1]);
    //  rgb.b = (YCbCr[0] * kColorConversion709[0][2]) + (YCbCr[1] * kColorConversion709[1][2]) + (YCbCr[2] * kColorConversion709[2][2]);
    
    rgb = saturate(rgb);
    
    // Note that gamma decoding seems to have very little impact
    // on performance since the entire shader is IO bound.
    
    return float4(rgb.r, rgb.g, rgb.b, 1.0f);
}

#define APPLE_GAMMA_196 (1.960938f)

static inline
float Apple196_nonLinearNormToLinear(float normV) {
  const float xIntercept = 0.05583828f;
  
  if (normV < xIntercept) {
    normV *= (1.0f / 16.0f);
  } else {
    const float gamma = APPLE_GAMMA_196;
    normV = pow(normV, gamma);
  }
  
  return normV;
}

static inline
float4 Apple196_gamma_decode(float4 rgba) {
  rgba.r = Apple196_nonLinearNormToLinear(rgba.r);
  rgba.g = Apple196_nonLinearNormToLinear(rgba.g);
  rgba.b = Apple196_nonLinearNormToLinear(rgba.b);
  return rgba;
}


fragment float4 fragmentShader(ImageColorInOut in [[ stage_in ]],
                               texture2d<float, access::sample> capturedImageTextureY [[ texture(0) ]],
                               texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(1) ]]) {
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float Y = capturedImageTextureY.sample(colorSampler, in.texCoord).r;
    float2 uvSamples = capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg;
    float Cb = uvSamples[0];
    float Cr = uvSamples[1];
    
    float4 pixel = BT709_decode(Y, Cb, Cr);
    
    // Return converted RGB color
    return Apple196_gamma_decode(pixel);
}
