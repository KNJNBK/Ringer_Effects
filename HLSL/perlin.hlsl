float2 hash2D(int2 p) {
  uint2 x = uint2(p);

  x = ((x >> 16) ^ x) * 0x45d9f3bB;
  x = ((x >> 16) ^ x) * 0x45d9f3bB;

  x ^= (x.yx >> 13);
  x *= uint2(0x45d9f3bBu, 0x7a86f2b1u);  
	x ^= (x.xy >> 11);
  x *= uint2(0x51d9f3bBu, 0x8a86f2b1u);

  float2 g = float2(x & 0x3FF) / 511.0 - 1.0;
  return normalize(g);
}

float perlinNoise2D(float2 p) {
  int2 i = int2(floor(p));
  float2 f = frac(p);

  // 5次補完曲線 
	float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

  float v00 = dot(hash2D(i + int2(0, 0)), f - float2(0, 0));
  float v10 = dot(hash2D(i + int2(1, 0)), f - float2(1, 0));
  float v01 = dot(hash2D(i + int2(0, 1)), f - float2(0, 1));
  float v11 = dot(hash2D(i + int2(1, 1)), f - float2(1, 1));

  return lerp(lerp(v00, v10, u.x), lerp(v01, v11, u.x), u.y);
}

float3 hash3D(int3 p) {
  uint3 x = uint3(p);

  x = ((x >> 16) ^ x) * 0x45d9f3bB;
  x = ((x >> 16) ^ x) * 0x45d9f3bB;

  x ^= (x.yzx >> 13);
  x *= uint3(0x1u, 0x45d9f3bBu, 0x7a86f2b1u); 
  x ^= (x.zxy >> 11);
  x *= uint3(0x9u, 0x51d9f3bBu, 0x8a86f2b1u);

  float3 g = float3(x & 0x3FF) / 511.0 - 1.0;
  return normalize(g);
}

float perlinNoise3D(float3 p) {
  int3 i = int3(floor(p));
  float3 f = frac(p);


  // 5次補完曲線 
  float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	// 各角にランダムな勾配ベクトルを生成
  float v000 = dot(hash3D(i + int3(0, 0, 0)), f - float3(0, 0, 0));
  float v100 = dot(hash3D(i + int3(1, 0, 0)), f - float3(1, 0, 0));
  float v010 = dot(hash3D(i + int3(0, 1, 0)), f - float3(0, 1, 0));
  float v110 = dot(hash3D(i + int3(1, 1, 0)), f - float3(1, 1, 0));
  float v001 = dot(hash3D(i + int3(0, 0, 1)), f - float3(0, 0, 1));
  float v101 = dot(hash3D(i + int3(1, 0, 1)), f - float3(1, 0, 1));
  float v011 = dot(hash3D(i + int3(0, 1, 1)), f - float3(0, 1, 1));
  float v111 = dot(hash3D(i + int3(1, 1, 1)), f - float3(1, 1, 1));

	// トリリニア補完
  return lerp(lerp(lerp(v000, v100, u.x), lerp(v010, v110, u.x), u.y),
              lerp(lerp(v001, v101, u.x), lerp(v011, v111, u.x), u.y), u.z);
}

// ノイズを重ねるFBM関す
float fbmNoise3D(float3 p, int octaves, float lacunarity, float gain) {
  float totalValue = 0.0;
  float currentAmp = 0.5;
  float currentFreq = 1.0;
  float maxValue = 0.0; 

  for (int i = 0; i < octaves; i++) {
    float noiseVal = perlinNoise3D(p * currentFreq);

    totalValue += noiseVal * currentAmp;

    maxValue += currentAmp;

    currentFreq *= lacunarity;
    currentAmp *= gain;   }

  return totalValue / maxValue;
}

float2 worley_offset(int2 p, float time) {
  // constant for the fragment at p
  float time_offset = 2.789612 * hash2D(100 * p).y;
  float current_time = time_offset + (1.0 + 0.2 * frac(time_offset.x)) * time;

  int current_time_step = int(floor(current_time));
  int next_time_step = int(current_time_step) + 1;

  float2 previous_position = hash2D(int2(current_time_step, current_time_step));
  float2 next_position = hash2D(int2(next_time_step, next_time_step));
  float interpolation_time = frac(current_time);

  float u = interpolation_time * interpolation_time * interpolation_time *
            (interpolation_time * (interpolation_time * 6.0 - 15.0) + 10.0);

  float2 current_position = lerp(previous_position, next_position, u);
  return current_position;
}

float animated_worley_noise(float2 p, float frequency, float time) {

  float2 sample_pt = frequency * p;
  float2 q = floor(sample_pt);

  // 角の座標
	float2 c0 = q + float2(0, 0);
  float2 c1 = q + float2(0, 1);
  float2 c2 = q + float2(1, 1);
  float2 c3 = q + float2(1, 0);
  float2 c4 = q + float2(1, -1);
  float2 c5 = q + float2(0, -1);
  float2 c6 = q + float2(-1, -1);
  float2 c7 = q + float2(-1, 0);
  float2 c8 = q + float2(-1, 1);

  // 角からずらした点
  float2 p0 = c0 + float2(0.5, 0.5) + worley_offset((int2)c0, time) / 2.0;
  float2 p1 = c1 + float2(0.5, 0.5) + worley_offset((int2)c1, time) / 2.0;
  float2 p2 = c2 + float2(0.5, 0.5) + worley_offset((int2)c2, time) / 2.0;
  float2 p3 = c3 + float2(0.5, 0.5) + worley_offset((int2)c3, time) / 2.0;
  float2 p4 = c4 + float2(0.5, 0.5) + worley_offset((int2)c4, time) / 2.0;
  float2 p5 = c5 + float2(0.5, 0.5) + worley_offset((int2)c5, time) / 2.0;
  float2 p6 = c6 + float2(0.5, 0.5) + worley_offset((int2)c6, time) / 2.0;
  float2 p7 = c7 + float2(0.5, 0.5) + worley_offset((int2)c7, time) / 2.0;
  float2 p8 = c8 + float2(0.5, 0.5) + worley_offset((int2)c8, time) / 2.0;

  // 距離
  float d0 = length(sample_pt - p0);
  float d1 = length(sample_pt - p1);
  float d2 = length(sample_pt - p2);
  float d3 = length(sample_pt - p3);
  float d4 = length(sample_pt - p4);
  float d5 = length(sample_pt - p5);
  float d6 = length(sample_pt - p6);
  float d7 = length(sample_pt - p7);
  float d8 = length(sample_pt - p8);

	//最短距離を算出
  return min(min(min(min(d0, d1), min(d2, d3)), min(min(d4, d5), min(d6, d7))),
             d8);
}

float fbm_worley(float2 p, int octaves, float lacunarity, float gain,
                 float time) {
  float totalValue = 0.0;
  float currentAmp = 0.5;
  float currentFreq = 1.0;
  float maxValue = 0.0; 

  for (int i = 0; i < octaves; i++) {
    float noiseVal = animated_worley_noise(p, currentFreq, time);

    totalValue += noiseVal * currentAmp;

    maxValue += currentAmp;

    currentFreq *= lacunarity;
    currentAmp *= gain;   }

  return totalValue / maxValue;
}
