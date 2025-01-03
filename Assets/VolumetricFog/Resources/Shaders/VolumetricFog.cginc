#ifndef VOLUMETRIC_FOG_INCLUDED
#define VOLUMETRIC_FOG_INCLUDED

 // Rest of shader follows - do not touch !

 #include "UnityCG.cginc"
 #include "VolumetricFogOptions.cginc"

 #undef SAMPLE_DEPTH_TEXTURE
 #define SAMPLE_DEPTH_TEXTURE(sampler,uv) SAMPLE_DEPTH_TEXTURE_LOD(sampler, float4(uv, 0, 0))

 #include "Shadows.cginc"
 #include "Surface.cginc"

 #define WEBGL_ITERATIONS 100
 #define ZEROS 0.0.xxxx
 #define dot2(x) dot(x,x)


    // Core uniforms!
    #ifndef OVERLAY_FOG
     UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex);
     float4     _MainTex_TexelSize;
     float4     _MainTex_ST;
        UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
        float4 _CameraDepthTexture_TexelSize;
        #if FOG_COMPUTE_DEPTH
            sampler2D_float _VolumetricFogDepthTexture;
        #endif
        UNITY_DECLARE_SCREENSPACE_TEXTURE(_FogDownsampled);
        UNITY_DECLARE_SCREENSPACE_TEXTURE(_DownsampledDepth);
        float4 _DownsampledDepth_TexelSize;
        float4x4 _ClipToWorld;
        float3     _ClipDir;

      #if FOG_BLUR_ON
        UNITY_DECLARE_SCREENSPACE_TEXTURE(_BlurTex); // was sampler2D
     #endif
   #else

   #if FOG_BLUR_ON
     sampler2D _BlurTex;
   #endif

    #endif

 sampler2D  _NoiseTex;
 half   _FogAlpha;
 half4  _FogColor;
 half   _DeepObscurance;
 float4 _FogDistance;    
 float4 _FogData; // x = _FogBaseHeight, y = _FogHeight, z = density, w = scale;
 float3 _FogWindDir;
 float4 _FogStepping; // x = stepping, y = stepping near, z = edge improvement threshold, w = dithering on (>0 = dithering intensity)
 float4 _FogSkyData; // x = haze, y = noise, z = speed, w = depth (note, need to be available for all shader variants)
 half   _FogSkyNoiseScale;

 #if FOG_VOID_SPHERE || FOG_VOID_BOX
 float3 _FogVoidPosition;    // xyz
 float4 _FogVoidData;
 #endif

 #if FOG_AREA_SPHERE || FOG_AREA_BOX
 float3 _FogAreaPosition;    // xyz
 float4 _FogAreaData;
 #endif

 #if FOG_HAZE_ON
 half4  _FogSkyColor;
 #endif
 
    #if FOG_OF_WAR_ON 
    sampler2D _FogOfWar;
    float3 _FogOfWarCenter;
    float3 _FogOfWarSize;
    float3 _FogOfWarCenterAdjusted;
    #endif
    
    #if FOG_POINT_LIGHTS
    float4 _FogPointLightPosition[FOG_MAX_POINT_LIGHTS];
    half4 _FogPointLightColor[FOG_MAX_POINT_LIGHTS];
    float _PointLightInsideAtten;
    #endif

    #if FOG_SCATTERING_ON || defined(FOG_DIFFUSION)
 float3 _SunPosition;
 float3 _SunPositionRightEye;
 float3 _SunDir;
 half3  _SunColor;
    half4 _FogScatteringData;    // x = 1 / samples * spread, y = samples, z = exposure, w = weight
    half4 _FogScatteringData2;  // x = illumination, y = decay, z = jitter, w = diffusion
    half4 _FogScatteringTint;   // rgb = color, a = tint intensity
        #ifndef OVERLAY_FOG
            UNITY_DECLARE_SCREENSPACE_TEXTURE(_ShaftTex);
        #else
            sampler2D _ShaftTex;
        #endif
    #endif

 float _Jitter;

 #if defined(FOG_MASK) || defined(FOG_INVERTED_MASK)
 UNITY_DECLARE_DEPTH_TEXTURE(_VolumetricFogScreenMaskTexture);
 #endif

 // Computed internally
 float3 wsCameraPos;
 float dither;
 float4 adir;

    #ifndef OVERLAY_FOG

 // Structures!
    struct appdata {
     float4 vertex : POSITION;
     float2 texcoord : TEXCOORD0;
     UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
 struct v2f {
     float4 pos : SV_POSITION;
     float2 uv: TEXCOORD0;
     float2 depthUV : TEXCOORD1;
     float3 cameraToFarPlane : TEXCOORD2;
     float2 depthUVNonStereo : TEXCOORD3;
     UNITY_VERTEX_INPUT_INSTANCE_ID
     UNITY_VERTEX_OUTPUT_STEREO
 };
 
 // the Vertex shader
 float3 _FlickerFreeCamPos;
 
 v2f vert(appdata v) {
     v2f o;
     UNITY_SETUP_INSTANCE_ID(v);
     UNITY_TRANSFER_INSTANCE_ID(v, o);
     UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
     o.pos = UnityObjectToClipPos(v.vertex);
     o.uv = UnityStereoScreenSpaceUVAdjust(v.texcoord, _MainTex_ST);
     o.depthUV = o.uv;
     o.depthUVNonStereo = v.texcoord;

     #if UNITY_UV_STARTS_AT_TOP
     if (_MainTex_TexelSize.y < 0) {
         // Depth texture is inverted WRT the main texture
         o.depthUV.y = 1.0 - o.depthUV.y;
         o.depthUVNonStereo.y = 1.0 - o.depthUVNonStereo.y;
     }
     #endif
               
     // Clip space X and Y coords
     float2 clipXY = o.pos.xy / o.pos.w;
               
     // Position of the far plane in clip space
     float4 farPlaneClip = float4(clipXY, 1.0, 1.0);
               
     // Homogeneous world position on the far plane
     farPlaneClip.y *= _ProjectionParams.x;  

     #if UNITY_SINGLE_PASS_STEREO || defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        _ClipToWorld = mul(_ClipToWorld, unity_CameraInvProjection);
     #endif
     float4 farPlaneWorld4 = mul(_ClipToWorld, farPlaneClip);
               
     // World position on the far plane
     float3 farPlaneWorld = farPlaneWorld4.xyz / farPlaneWorld4.w;
               
     // Vector from the camera to the far plane
     o.cameraToFarPlane = farPlaneWorld - _WorldSpaceCameraPos + _FlickerFreeCamPos;
     
     return o;
 }


 // Misc functions

 float3 getWorldPos(v2f i, float depth01) {
     // Reconstruct the world position of the pixel
         #if FOG_USE_XY_PLANE
            wsCameraPos = float3(_WorldSpaceCameraPos.x, _WorldSpaceCameraPos.y, _WorldSpaceCameraPos.z - _FogData.x);
            #if defined(FOG_ORTHO)
                float3 worldPos = i.cameraToFarPlane - _ClipDir * (_ProjectionParams.z * (1.0 - depth01)) + wsCameraPos;
                wsCameraPos += i.cameraToFarPlane - _ClipDir * _ProjectionParams.z;
            #else
                float3 worldPos = (i.cameraToFarPlane * depth01) + wsCameraPos;
            #endif
            worldPos.z += 0.00001; // fixes artifacts when worldPos.y = _WorldSpaceCameraPos.y which is really rare but occurs at y = 0
         #else
            wsCameraPos = float3(_WorldSpaceCameraPos.x, _WorldSpaceCameraPos.y - _FogData.x, _WorldSpaceCameraPos.z);
            #if defined(FOG_ORTHO)
                float3 worldPos;
                if (unity_OrthoParams.w) {
                    worldPos = i.cameraToFarPlane - _ClipDir * (_ProjectionParams.z * (1.0 - depth01)) + wsCameraPos;
                    wsCameraPos += i.cameraToFarPlane - _ClipDir * _ProjectionParams.z;
                } else {
                    worldPos = (i.cameraToFarPlane * depth01) + wsCameraPos;
                }
            #else
                float3 worldPos = (i.cameraToFarPlane * depth01) + wsCameraPos;
            #endif
            worldPos.y += 0.00001; // fixes artifacts when worldPos.y = _WorldSpaceCameraPos.y which is really rare but occurs at y = 0
         #endif
     return worldPos;
    }
    
 #if FOG_HAZE_ON
 half4 getSkyColor(float3 worldPos, float2 uv) {
     // Compute sky color
     float y = 1.0 / max(worldPos.y + _FogData.x, 1.0);
     float2 np = worldPos.xz * y * _FogSkyNoiseScale + _FogSkyData.z;
     float skyNoise = tex2D(_NoiseTex, np).a;
     //skyNoise += dither * 3.0 * _FogStepping.w; // disabled to artifacts on bright fog, no need since dither is applied early
     half t = saturate( _FogSkyData.x * y * (1.0 - skyNoise * _FogSkyData.y) );
     return _FogSkyColor * (t * _FogSkyColor.a);
 }
 #endif


    inline float getDepth(v2f i) {
        #if defined(FOG_ORTHO)
            float depth01 = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV));
            #if UNITY_REVERSED_Z
                depth01 = 1.0 - depth01;
            #endif
        #else
            float depth01 = Linear01Depth(UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV)));
        #endif
        return depth01;
    }


    #if defined(FOG_MASK) || defined(FOG_INVERTED_MASK)
    inline float GetDepthMask(float2 uv) {
        #if defined(FOG_ORTHO)
            float depthMask = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_VolumetricFogScreenMaskTexture, uv));
            #if UNITY_REVERSED_Z
                depthMask = 1.0 - depthMask;
            #endif
        #else
            float depthMask = Linear01Depth(UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_VolumetricFogScreenMaskTexture, uv)));
        #endif
        return depthMask;
    }
    #endif

    #endif  // OVERLAY_FOG


 #if FOG_SCATTERING_ON
 
 #if defined(FOG_SMOOTH_SCATTERING) 
 #define COMPUTE_SHAFT UNITY_SAMPLE_SCREENSPACE_TEXTURE(_ShaftTex, i.depthUV).rgb
 #else
 #define COMPUTE_SHAFT getShaft(i.uv)
 #endif
     
 half3 getShaft(float2 uv) {
     _SunPosition.xy = unity_StereoEyeIndex == 0 ? _SunPosition.xy : _SunPositionRightEye.xy;
     #if UNITY_SINGLE_PASS_STEREO || defined(UNITY_STEREO_INSTANCING_ENABLED)
         _SunPosition.xy = UnityStereoScreenSpaceUVAdjust(_SunPosition.xy, _MainTex_ST);
     #endif
     #if UNITY_UV_STARTS_AT_TOP
     if (_MainTex_TexelSize.y < 0) {
         _SunPosition.y = 1.0 - _SunPosition.y;
     }
     #endif
     float2 duv = _SunPosition.xy - uv;
     duv *= _FogScatteringData.x * (1.0 + dither * _FogScatteringData2.z);  
     half illumination = _FogScatteringData2.x;
     half3 acum = half3(0,0,0);
     for (float i = _FogScatteringData.y; i > 0; i--) {
        uv += duv;  
        half4 rgba = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_MainTex, float4(uv.xy,0,0));   // was tex2Dlod
        acum += max(0.0.xxx, rgba.rgb) * (illumination * _FogScatteringData.w);
        illumination *= _FogScatteringData2.y;
     }  
     half3 shaft = acum * _FogScatteringData.z;
     shaft = lerp(shaft, shaft.g * _FogScatteringTint.rgb, _FogScatteringTint.a);
     return shaft;
 }
 #endif
 
 #if defined(FOG_DIFFUSION)
 void applyDiffusion(inout half4 sum) {
     float sunAmount = max( (dot( adir.xyz/adir.w, _SunDir)) * _FogScatteringData2.w, 0.0 );
     sum.rgb += _SunColor.rgb * (pow(sunAmount, 8.0) * sum.a);
 }
 #endif


 float minimum_distance_sqr(float fogLengthSqr, float3 w, float3 p) {
     // Return minimum distance between line segment vw and point p
     float t = saturate(dot(p, w) / fogLengthSqr); 
     float3 projection = t * w;
     return dot2(p - projection);
 }

half4 getFogColor(float3 worldPos, float depth01) {

     adir = float4(worldPos - wsCameraPos, 0);
     adir.w = length(adir.xyz);

     // early exit if fog is not crossed
#if FOG_USE_XY_PLANE
     if ( (wsCameraPos.z>_FogData.y && worldPos.z>_FogData.y) ||
          (wsCameraPos.z<-_FogData.y && worldPos.z<-_FogData.y) ) {
         return ZEROS;       
     }
#else
     if ( (wsCameraPos.y>_FogData.y && worldPos.y>_FogData.y) ||
          (wsCameraPos.y<-_FogData.y && worldPos.y<-_FogData.y) ) {
         return ZEROS;       
     }
#endif
                  
     half voidAlpha = _FogAlpha; // 1.0;
                 
     #if FOG_OF_WAR_ON
        #if !defined(FOG_OF_WAR_HEAVY_LOOP)
            if (depth01<_FogSkyData.w) {
                #if FOG_USE_XY_PLANE
                    float2 fogTexCoord = worldPos.xy / _FogOfWarSize.xy - _FogOfWarCenterAdjusted.xy;
                #else
                    float2 fogTexCoord = worldPos.xz / _FogOfWarSize.xz - _FogOfWarCenterAdjusted.xz;
                #endif
                voidAlpha = tex2D(_FogOfWar, fogTexCoord).a;
                if (voidAlpha <=0) return ZEROS;
            }
        #endif
     #endif
     
     // Determine "fog length" and initial ray position between object and camera, cutting by fog distance params
     #if FOG_AREA_SPHERE
         // compute sphere intersection or early exit if ray does not sphere
         float3  oc = wsCameraPos - _FogAreaPosition;
         float3 nadir = adir.xyz / adir.w;
         float   b = dot(nadir, oc);
         float   c = dot2(oc) - _FogAreaData.y;
         float   t = b*b - c;
         if (t>=0) t = sqrt(t);
         float distanceToFog = max(-b-t, 0);
         float dist  = min(adir.w, _FogDistance.z);
         float t1 = min(-b+t, dist);
         float fogLength = t1 - distanceToFog;
         if (fogLength<0) return ZEROS;
         float3 fogCeilingCut = wsCameraPos + nadir * distanceToFog;
     #elif FOG_AREA_BOX
         // compute box intersectionor early exit if ray does not cross box
         float3 ro = wsCameraPos - _FogAreaPosition;
         float3 invR   = adir.w / adir.xyz;
         float3 boxmax = 1.0 / _FogAreaData.xyz;
         float3 tbot   = invR * (-boxmax - ro);
         float3 ttop   = invR * (boxmax - ro);
         float3 tmin   = min (ttop, tbot);
         float2 tt0    = max (tmin.xx, tmin.yz);
         float distanceToFog  = max(tt0.x, tt0.y);
         distanceToFog = max(distanceToFog, 0);
         float3 tmax   = max (ttop, tbot);
         tt0 = min (tmax.xx, tmax.yz);
         float t1  = min(tt0.x, tt0.y);  
         float dist  = min(adir.w, _FogDistance.z);
         t1 = min(t1, dist);
         float fogLength = t1 - distanceToFog;
         if (fogLength<=0) return ZEROS;
         float3 fogCeilingCut = wsCameraPos + distanceToFog / invR;
         #if FOG_USE_XY_PLANE
             _FogAreaData.xy /= _FogData.w;
         #else
             _FogAreaData.xz /= _FogData.w;
         #endif
     #else 
     
         // ceiling cut
#if FOG_USE_XY_PLANE
         float h = clamp(wsCameraPos.z, -_FogData.y, _FogData.y);
         float distanceToFog = (h - wsCameraPos.z) * adir.w / adir.z;
         float3 fogCeilingCut = wsCameraPos + (distanceToFog/adir.w) * adir.xyz;
#else
         float h = clamp(wsCameraPos.y, -_FogData.y, _FogData.y);
         float distanceToFog = (h - wsCameraPos.y) * adir.w / adir.y;
         float3 fogCeilingCut = wsCameraPos + (distanceToFog/adir.w) * adir.xyz;
#endif

         // does fog starts after pixel? If it does, exit now
         float dist  = min(adir.w, _FogDistance.z);
         if (distanceToFog>=dist) return ZEROS;

         // floor cut
         float hf = 0;
#if FOG_USE_XY_PLANE 
         // edge cases
         if (adir.z > 0 && worldPos.z > -0.5) {
             hf = _FogData.y;
         }
         if (adir.z < 0 && worldPos.z < 0.5) {
             hf = - _FogData.y;
         }
         float tfloor = (hf - wsCameraPos.z) * adir.w / adir.z;
#else
         // edge cases
         if (adir.y > 0 && worldPos.y > -0.5) {
             hf = _FogData.y;
         }
         if (adir.y < 0 && worldPos.y < 0.5) {
             hf = - _FogData.y;
         }
         float tfloor = (hf - wsCameraPos.y) * adir.w / adir.y;
#endif

         // fog length is...
         float fogLength = tfloor - distanceToFog;
         fogLength = min(fogLength, dist - distanceToFog);
         if (fogLength<=0) return ZEROS;

     #endif
     
     float3 fogEndPosWS = fogCeilingCut + adir.xyz * (fogLength/adir.w);
     #if !defined(FOG_VOID_HEAVY_LOOP)
         #if FOG_VOID_SPHERE
            float voidDistance = distance(_FogVoidPosition, fogEndPosWS) * _FogVoidData.x;
            voidAlpha *= saturate(lerp(1.0, voidDistance, _FogVoidData.w));
            if (voidAlpha <= 0) return ZEROS;
        #elif FOG_VOID_BOX
            float3 absPos = abs(_FogVoidPosition - fogEndPosWS) * _FogVoidData.xyz;
            float voidDistance = max(max(absPos.x, absPos.y), absPos.z);
            voidAlpha *= saturate(lerp(1.0, voidDistance, _FogVoidData.w));
            if (voidAlpha <= 0) return ZEROS;
        #endif      
     #endif

     // Calc Ray-march params
     float rs = 0.1 + max( log(fogLength), 0 ) * _FogStepping.x;     // stepping ratio with atten detail with distance
     rs *= _FogData.z;   // prevents lag when density is too low
     rs *= saturate (dist * _FogStepping.y);
     dist -= distanceToFog;
     rs = max(rs, 0.01);
     float4 dir = float4( adir.xyz * (rs / adir.w), fogLength / rs);       // ray direction & length
//       dir.w = min(dir.w, 200);    // maximum iterations could be clamped to improve performance under some point of view, most of time got unnoticieable

     #if !FOG_AREA_SPHERE && !FOG_AREA_BOX
     // distance blending
        voidAlpha *= saturate(pow((_FogDistance.z - distance(wsCameraPos.xz, fogCeilingCut.xz)) / _FogDistance.w, 4));
     #endif

#if !defined(FOG_AREA_NOISE_USES_WORLD_SPACE) && (FOG_AREA_SPHERE || FOG_AREA_BOX)
    #define FOG_AREA_LOCAL_SPACE _FogAreaPosition
#else
    #define FOG_AREA_LOCAL_SPACE 0.0.xxx
#endif

     // Fit to surface preparation
     SurfaceComputeEndPoints(fogEndPosWS, fogCeilingCut, dir.w, _FogData.y);

     // Extracted operations from ray-march loop for additional optimizations
#if FOG_USE_XY_PLANE
     dir.xy  *= _FogData.w;
     _FogData.y *= _FogData.z;   // extracted from loop, dragged here.
     dir.z   /= _FogData.y;
     float4 ft4 = float4(fogCeilingCut - FOG_AREA_LOCAL_SPACE, 0); 
     ft4.xy  *= _FogData.w;
     ft4.xy  += _FogWindDir.xz;  // apply wind speed and direction; already defined above if the condition is true
     ft4.z   /= _FogData.y;  
#else
     dir.xz  *= _FogData.w;
     _FogData.y *= _FogData.z;   // extracted from loop, dragged here.
     dir.y   /= _FogData.y;
     float4 ft4 = float4(fogCeilingCut - FOG_AREA_LOCAL_SPACE, 0); 
     ft4.xz  *= _FogData.w;
     ft4.xz  += _FogWindDir.xz;  // apply wind speed and direction; already defined above if the condition is true
     ft4.y   /= _FogData.y;  
#endif

#if FOG_USE_XY_PLANE
     #if FOG_AREA_SPHERE || FOG_AREA_BOX
         float2 areaCenter = _FogAreaPosition.xy - FOG_AREA_LOCAL_SPACE.xy;
         areaCenter *= _FogData.w;
         areaCenter += _FogWindDir.xy;
     #endif
     #if FOG_DISTANCE_ON || defined(FOG_MASK) || defined(FOG_INVERTED_MASK)
         float2 camCenter = wsCameraPos.xy;
         camCenter *= _FogData.w;
         camCenter += _FogWindDir.xy;
     #endif
#else
     #if FOG_AREA_SPHERE || FOG_AREA_BOX
         float2 areaCenter = _FogAreaPosition.xz - FOG_AREA_LOCAL_SPACE.xz;
         areaCenter *= _FogData.w;
         areaCenter += _FogWindDir.xz;
     #endif
     #if FOG_DISTANCE_ON || defined(FOG_MASK) || defined(FOG_INVERTED_MASK)
         float2 camCenter = wsCameraPos.xz;
         camCenter *= _FogData.w;
         camCenter += _FogWindDir.xz;
     #endif
#endif

#if defined(FOG_VOID_HEAVY_LOOP)
     #if FOG_VOID_SPHERE || FOG_VOID_BOX
        float2 voidCenter = _FogVoidPosition.xz;
        voidCenter *= _FogData.w;
        voidCenter += _FogWindDir.xz;
        _FogVoidData.xyz /= _FogData.w;
        #if FOG_VOID_SPHERE
            _FogVoidData.x *= _FogVoidData.x; // due to distance being computed as dot(x,x)
        #endif
     #endif
#endif

     // reduce banding; apply always to prevent it in any feature combination
     //#if FOG_SUN_SHADOWS_ON || FOG_AREA_SPHERE || FOG_AREA_BOX
     dir.w += frac(dither) * _Jitter;
     //#endif

     // Shadow preparation
     #if FOG_SUN_SHADOWS_ON
         #if FOG_USE_XY_PLANE
             fogCeilingCut.z += _FogData.x;
         #else
             fogCeilingCut.y += _FogData.x;
         #endif
//           dir.w += frac(dither); // extra banding reduction (not really needed since jitter was introduced but just in case it's needed... here it's)
       float3 fogEndPos = fogCeilingCut + adir.xyz * (fogLength * (1.0 + dither * _VolumetricFogSunShadowsData.y) / adir.w);
       _VolumetricFogSunShadowsData.w = 1.0 / dir.w;

        #if defined(FOG_UNITY_DIR_SHADOWS)
            float3 shadowWPOS0 = fogCeilingCut;
            float3 shadowWPOS1 = fogEndPos;
        #else
            float3 shadowCoords0 = getShadowCoords(fogCeilingCut);
            float3 shadowCoords1 = getShadowCoords(fogEndPos);
         #endif
     #endif
     
     // Ray-march
     half4 sum   = ZEROS;
     half4 fgCol = ZEROS;
     
     #if SHADER_API_GLES
     for(int k=0;k<WEBGL_ITERATIONS;k++) {
     if (dir.w>1) {
     #else
     for (;dir.w>1;dir.w--,ft4.xyz+=dir.xyz) {
     #endif

         float fy = SurfaceApply(ft4.y, _FogData.x, dir.w);
         #if FOG_AREA_SPHERE

             #if FOG_USE_XY_PLANE
                 float2 ad = (areaCenter - ft4.xy) * _FogAreaData.x;
             #else
                 float2 ad = (areaCenter - ft4.xz) * _FogAreaData.x;
             #endif
             float areaDistance = dot2(ad);

             #if FOG_USE_XY_PLANE
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xyww);
                 ng.a -= abs(ft4.z) + areaDistance * _FogAreaData.w;
             #else
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xzww);
                 ng.a -= abs(fy) + areaDistance * _FogAreaData.w;
             #endif

         #elif FOG_AREA_BOX

             #if FOG_USE_XY_PLANE
                 float2 ad = abs(areaCenter - ft4.xy) * _FogAreaData.xy;
             #else
                 float2 ad = abs(areaCenter - ft4.xz) * _FogAreaData.xz;
             #endif
             float areaDistance = max(ad.x, ad.y);

             #if FOG_USE_XY_PLANE
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xyww);
                 ng.a -= abs(ft4.z) + areaDistance * _FogAreaData.w;
             #else
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xzww);
                 ng.a -= abs(fy) + areaDistance * _FogAreaData.w;
             #endif

         #else

             #if FOG_USE_XY_PLANE
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xyww);
                 ng.a -= abs(ft4.z);
             #else
                 half4 ng = tex2Dlod(_NoiseTex, ft4.xzww);
                 ng.a -= abs(ft4.y);
             #endif

         #endif

         #if FOG_DISTANCE_ON
            #if FOG_USE_XY_PLANE
                float2 fd = camCenter - ft4.xy;
            #else
                float2 fd = camCenter - ft4.xz;
            #endif
            float fdsqr = dot2(fd);
            float fdm = max(_FogDistance.x - fdsqr, 0) * _FogDistance.y;
            ng.a -= fdm;
         #endif
         
         if (ng.a > 0) {
            fgCol =  _FogColor * half4((1.0-ng.a*_DeepObscurance).xxx, ng.a);
            
             #if FOG_SUN_SHADOWS_ON
                 float t = dir.w * _VolumetricFogSunShadowsData.w;

                 #if defined(FOG_UNITY_DIR_SHADOWS)
                     //*** Unity shadow ***
                     float3 shadowPos = lerp(shadowWPOS1, shadowWPOS0, t);
                     float shadowFade = GetShadowFade(shadowPos);
                     if (shadowFade < 1.0) {
                        float shadowAtten = GetLightAttenuation(shadowPos, shadowFade);
                        ng.rgb *= lerp(1.0, shadowAtten, _VolumetricFogSunShadowsData.x * sum.a);
                        fgCol.a *= lerp(1.0, shadowAtten, _VolumetricFogSunShadowsData.z );
                     }
                 #else
                     // *** Custom Sun shadows ***
                     float3 curPos = lerp(fogEndPos, fogCeilingCut, t);
                     float shadowFade = saturate(dot2(curPos - _VolumetricFogSunShadowsCameraWorldPos) - _VolumetricFogSunWorldPos.w);
                     if (shadowFade < 1.0) {
                        float3 shadowCoords = lerp(shadowCoords1, shadowCoords0, t);
                        float4 sunDepthWorldPos = tex2Dlod(_VolumetricFogSunDepthTexture, shadowCoords.xyzz);
                        float sunDepth = 1.0 / DecodeFloatRGBA(sunDepthWorldPos);
                        float sunDist = distance(curPos, _VolumetricFogSunWorldPos.xyz);
                        float shadowAtten = saturate(sunDepth - sunDist);
                        shadowAtten = saturate(shadowAtten + shadowFade);
                        ng.rgb *= lerp(1.0, shadowAtten, _VolumetricFogSunShadowsData.x * sum.a);
                        fgCol.a *= lerp(1.0, shadowAtten, _VolumetricFogSunShadowsData.z );
                     }
                 #endif
             #endif

             #if defined(FOG_VOID_HEAVY_LOOP)
               #if FOG_VOID_SPHERE
                    float2 vd = voidCenter - ft4.xz;
                    float voidDistance = dot2(vd) * _FogVoidData.x;
                    fgCol.a *= saturate(lerp(1.0, voidDistance, _FogVoidData.w));
               #elif FOG_VOID_BOX
                    float2 absPos = abs(voidCenter - ft4.xz) * _FogVoidData.xz;
                    float voidDistance = max(absPos.x, absPos.y);
                    fgCol.a *= saturate(lerp(1.0, voidDistance, _FogVoidData.w));
               #endif
             #endif

             #if FOG_OF_WAR_ON
                #if defined(FOG_OF_WAR_HEAVY_LOOP)
                    #if FOG_USE_XY_PLANE
                        float2 worldPosXY = ft4.xy;
                        worldPosXY -= _FogWindDir.xz;
                        worldPosXY /= _FogData.w;
                        float2 fogTexCoord = worldPosXY / _FogOfWarSize.xy - _FogOfWarCenterAdjusted.xy;
                    #else
                        float2 worldPosXZ = ft4.xz;
                        worldPosXZ -= _FogWindDir.xz;
                        worldPosXZ /= _FogData.w;
                        float2 fogTexCoord = worldPosXZ / _FogOfWarSize.xz - _FogOfWarCenterAdjusted.xz;
                    #endif
                    fgCol.a *= tex2Dlod(_FogOfWar, float4(fogTexCoord, 0, 0)).a;
                #endif
             #endif

             fgCol.rgb *= ng.rgb * fgCol.aaa;
             sum += fgCol * (1.0-sum.a);
             if (sum.a>0.99) break;
         }

         #if SHADER_API_GLES
            dir.w--;
            ft4.xyz+=dir.xyz;
            }
         #endif
     }
     
     #ifndef OVERLAY_FOG
     // adds fog fraction to prevent banding due stepping on low densities
//       sum += (fogLength >= dist) * (sum.a<0.99) * fgCol * (1.0-sum.a) * dir.w; // if fog hits geometry and accumulation is less than 0.99 add remaining fraction to reduce banding
     half f1 = (sum.a<0.99);
     half oneMinusSumAmount = 1.0-sum.a;
     half fogLengthExceedsDist = (fogLength >= dist);
     half f3 = (half)(fogLengthExceedsDist * dir.w);
     sum += fgCol * (f1 * oneMinusSumAmount * f3);
    #endif
        
     // Point light preparation
     #if FOG_POINT_LIGHTS
         float3 pldir = adir.xyz / adir.w;
         fogCeilingCut += pldir * _PointLightInsideAtten;
         fogLength -= _PointLightInsideAtten;
         pldir *= fogLength;
         float fogLengthSqr = fogLength * fogLength;
         for (int k=0;k<FOG_MAX_POINT_LIGHTS;k++) {
             half pointLightInfluence = minimum_distance_sqr(fogLengthSqr, pldir, _FogPointLightPosition[k] - fogCeilingCut) / _FogPointLightColor[k].w;
             half scattering = sum.a / (1.0 + pointLightInfluence);
             sum.rgb += _FogPointLightColor[k].rgb * scattering;
         }
     #endif
     
     sum *= voidAlpha;
     
     return sum;
 }



sampler2D _BlueNoise;
float4 _BlueNoise_TexelSize;

inline void SetDither(float2 uv) {
    #if defined(FOG_BLUE_NOISE)
        float2 noiseUV = uv * _ScreenParams.xy * _BlueNoise_TexelSize.xy;
        dither = tex2Dlod(_BlueNoise, float4(noiseUV, 0, 0)).r - 0.5;
    #else
        dither = frac(dot(float2(2.4084507, 3.2535211), uv * _ScreenParams.xy)) - 0.5;
    #endif
}


 
 #ifndef OVERLAY_FOG

 // Fragment Shaders
 half4 fragBackFog(v2f i) : SV_Target{
 
     UNITY_SETUP_INSTANCE_ID(i);
	 UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
     
     float depthOpaque = getDepth(i);
     #if FOG_COMPUTE_DEPTH
         float depthTex = Linear01Depth(UNITY_SAMPLE_DEPTH(tex2D(_VolumetricFogDepthTexture, i.depthUVNonStereo)));
         float depth01 = min(depthOpaque, depthTex);
     #else
         float depth01 = depthOpaque;
     #endif

     half4 color = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv);
     color = max(0.0.xxxx, color);

     #if defined(FOG_MASK)
           if (GetDepthMask(i.uv)>=depth01) return color;
     #elif defined(FOG_INVERTED_MASK)
           if (GetDepthMask(i.uv)<depth01) return color;
     #endif

     float3 worldPos = getWorldPos(i, depth01);

     SetDither(i.uv);
     
     half4 sum = getFogColor(worldPos, depth01);
     sum += dither * _FogStepping.w;
     
     #if defined(FOG_DEBUG)
        return sum;
     #endif

     #if FOG_BLUR_ON
        half4 blurColor = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_BlurTex, i.depthUV);
        color.rgb = lerp(color.rgb, blurColor.rgb, sum.a);
     #endif

     #if FOG_HAZE_ON
        half4 haze = getSkyColor(worldPos, i.uv);
        haze *= saturate( depth01 / _FogSkyData.w );
        sum = haze * (1.0 - sum.a) + sum;
     #endif
     
     #if defined(FOG_DIFFUSION)
         applyDiffusion(sum);
     #endif
     
     color.rgb = color.rgb * saturate(1.0 - sum.a) + sum.rgb;
    
     #if FOG_SCATTERING_ON
        color.rgb += COMPUTE_SHAFT;
     #endif
     color.a = sum.a; // required for the transparency blend option

     return color;
 }

 struct FragmentOutput
    {
        half4 dest0 : SV_Target0;
        float4 dest1 : SV_Target1;
    };
     
 FragmentOutput fragGetFog (v2f i) {
     UNITY_SETUP_INSTANCE_ID(i);
	 UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

     float depthFull = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0,-0.75) * _CameraDepthTexture_TexelSize.xy));
     float depthFull2 = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0,0.75) * _CameraDepthTexture_TexelSize.xy)); // prevents artifacts on terrain under some perspective and high downsampling factor
     #if UNITY_REVERSED_Z
        depthFull = max(depthFull, depthFull2);
     #else
        depthFull = min(depthFull, depthFull2);
     #endif
     #if defined(FOG_ORTHO)
         float depth01  = depthFull;
     #else
         float depth01  = Linear01Depth(depthFull);
     #endif
     #if FOG_COMPUTE_DEPTH
         float depthTex = Linear01Depth(UNITY_SAMPLE_DEPTH(tex2D(_VolumetricFogDepthTexture, i.depthUVNonStereo)));
         depth01 = min(depth01, depthTex);
     #endif

        #if defined(FOG_MASK)
        if (GetDepthMask(i.uv)>=depth01) {
            FragmentOutput o;
            o.dest0 = ZEROS;
            o.dest1 = ZEROS;
            return o;
        }
        #elif defined(FOG_INVERTED_MASK)
        if (GetDepthMask(i.uv)<depth01) {
            FragmentOutput o;
            o.dest0 = ZEROS;
            o.dest1 = ZEROS;
            return o;
        }
        #endif

     float3 worldPos = getWorldPos(i, depth01);
     
     //#if FOG_SUN_SHADOWS_ON
     SetDither(i.uv);
     //#endif
     
     half4 fogColor = getFogColor(worldPos, depth01);
     fogColor += dither * _FogStepping.w;
     FragmentOutput o;
     o.dest0 = fogColor;
     o.dest1 = depthFull.xxxx;
     return o;
 }

 half4 fragGetJustFog(v2f i) : SV_Target {
     UNITY_SETUP_INSTANCE_ID(i);
	 UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

     float depthFull = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0, -0.75) * _CameraDepthTexture_TexelSize.xy));
     float depthFull2 = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0, 0.75) * _CameraDepthTexture_TexelSize.xy)); // prevents artifacts on terrain under some perspective and high downsampling factor
     #if UNITY_REVERSED_Z
        depthFull = max(depthFull, depthFull2);
     #else
        depthFull = min(depthFull, depthFull2);
     #endif
     #if defined(FOG_ORTHO)
         float depth01  = depthFull;
     #else
         float depth01  = Linear01Depth(depthFull);
     #endif

     #if FOG_COMPUTE_DEPTH
         float depthTex = Linear01Depth(UNITY_SAMPLE_DEPTH(tex2D(_VolumetricFogDepthTexture, i.depthUVNonStereo)));
         depth01 = min(depth01, depthTex);
     #endif

        #if defined(FOG_MASK)
        if (GetDepthMask(i.uv)>=depth01) return ZEROS;
        #elif defined(FOG_INVERTED_MASK)
        if (GetDepthMask(i.uv)<depth01) return ZEROS;
        #endif
       
     float3 worldPos = getWorldPos(i, depth01);
     
     //#if FOG_SUN_SHADOWS_ON
     SetDither(i.uv);
     //#endif
     
     half4 sum = getFogColor(worldPos, depth01);
     sum += dither * _FogStepping.w;
     //sum *= 1.0 + dither * _FogStepping.w;
     return sum;
 }

 float4 fragGetJustDepth(v2f i) : SV_Target {
     UNITY_SETUP_INSTANCE_ID(i);
	 UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

     float depthFull = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0, -0.75) * _CameraDepthTexture_TexelSize.xy));
     float depthFull2 = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV + float2(0, 0.75) * _CameraDepthTexture_TexelSize.xy)); // prevents artifacts on terrain under some perspective and high downsampling factor
     #if UNITY_REVERSED_Z
         depthFull = max(depthFull, depthFull2);
     #else
         depthFull = min(depthFull, depthFull2);
     #endif

     #if FOG_COMPUTE_DEPTH
         float depthTex = UNITY_SAMPLE_DEPTH(tex2D(_VolumetricFogDepthTexture, i.depthUVNonStereo));
         #if UNITY_REVERSED_Z
             depthFull = max(depthTex, depthFull);
         #else
             depthFull = min(depthTex, depthFull);
         #endif
     #endif

     return depthFull.xxxx;
 }


 half4 fragApplyFog (v2f i) : SV_Target {
     UNITY_SETUP_INSTANCE_ID(i);
	 UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

     float depthFull = UNITY_SAMPLE_DEPTH(UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, i.depthUV));
     float2 minUV = i.depthUV;
         if (_FogStepping.z > 0) {
         float2 uv00 = i.depthUV - 0.5 * _DownsampledDepth_TexelSize.xy;
         float2 uv10 = uv00 + float2(_DownsampledDepth_TexelSize.x, 0);
         float2 uv01 = uv00 + float2(0, _DownsampledDepth_TexelSize.y);
         float2 uv11 = uv00 + _DownsampledDepth_TexelSize.xy;
         float4 depths;
         depths.x = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_DownsampledDepth, float4(uv00, 0, 0)).r; // was tex2Dlod
         depths.y = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_DownsampledDepth, float4(uv10, 0, 0)).r; // was tex2Dlod
         depths.z = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_DownsampledDepth, float4(uv01, 0, 0)).r; // was tex2Dlod
         depths.w = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_DownsampledDepth, float4(uv11, 0, 0)).r; // was tex2Dlod
         float4 diffs = abs(depthFull.xxxx - depths);
         if (any(diffs > _FogStepping.zzzz)) {
             // Check 10 vs 00
             float minDiff  = lerp(diffs.x, diffs.y, diffs.y < diffs.x);
             minUV    = lerp(uv00, uv10, diffs.y < diffs.x);
             // Check against 01
             minUV    = lerp(minUV, uv01, diffs.z < minDiff);
             minDiff  = lerp(minDiff, diffs.z, diffs.z < minDiff);
             // Check against 11
             minUV    = lerp(minUV, uv11, diffs.w < minDiff);
         }
     }
     half4 sum = SAMPLE_RAW_DEPTH_TEXTURE_LOD(_FogDownsampled, float4(minUV, 0, 0)); // was tex2Dlod
     SetDither(i.uv);
     sum += dither * _FogStepping.w;
     //sum *= 1.0 + dither * _FogStepping.w;

     #if defined(FOG_DEBUG)
         return sum;
     #endif
     
     half4 color = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv);
     color = max(0.0.xxxx, color);
     
 #if FOG_BLUR_ON
     half4 blurColor = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_BlurTex, i.depthUV);
     color.rgb = lerp(color.rgb, blurColor.rgb, sum.a);
 #endif

     #if FOG_HAZE_ON || defined(FOG_DIFFUSION)
         #if defined(FOG_ORTHO)
             float depthLinear01 = depthFull;
         #else
             float depthLinear01 = Linear01Depth(depthFull);
         #endif

         #if FOG_COMPUTE_DEPTH
             float depthTex = Linear01Depth(UNITY_SAMPLE_DEPTH(tex2D(_VolumetricFogDepthTexture, i.depthUVNonStereo)));
             depthLinear01 = min(depthTex, depthLinear01);
         #endif
         float3 worldPos = getWorldPos(i, depthLinear01);
     #endif
     
     
     #if FOG_HAZE_ON
         //if (depthLinear01>=_FogSkyData.w) {     
             half4 haze = getSkyColor(worldPos, i.uv);
             haze *= saturate( depthLinear01 / _FogSkyData.w );
             sum = haze * (1.0 - sum.a) + sum;
         //}
     #endif
     
     #if defined(FOG_DIFFUSION)
         adir = float4(worldPos - wsCameraPos, 0);
         adir.w = length(adir.xyz);
         applyDiffusion(sum);
     #endif

     color.rgb = color.rgb * saturate(1.0 - sum.a) + sum.rgb;

     #if FOG_SCATTERING_ON
         color.rgb += COMPUTE_SHAFT;
     #endif

     color.a = sum.a; // required for the transparency blend option

     return color;
 }
 
  half4 fragGetJustShaft(v2f i) : SV_Target{
     UNITY_SETUP_INSTANCE_ID(i);
     UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
     
     SetDither(i.uv);
     
     #if FOG_SCATTERING_ON
     half4 color = half4(getShaft(i.uv), 1.0);
        return color;
     #else
        return 0.0.xxxx;
     #endif
 }
 
 
    struct v2fCross {
        float4 pos : SV_POSITION;
        half2 uv: TEXCOORD0;
        half2 uv1: TEXCOORD1;
        half2 uv2: TEXCOORD2;
        half2 uv3: TEXCOORD3;
        half2 uv4: TEXCOORD4;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };
    
    #define _BlurScale 2.0
  
    v2fCross vertBlurH(appdata v) {
        v2fCross o;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_TRANSFER_INSTANCE_ID(v, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        o.pos = UnityObjectToClipPos(v.vertex);
        #if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0) {
            // Texture is inverted WRT the main texture
            v.texcoord.y = 1.0 - v.texcoord.y;
        }
        #endif   
        o.uv = UnityStereoScreenSpaceUVAdjust(v.texcoord, _MainTex_ST);
        half2 inc = half2(_MainTex_TexelSize.x * 1.3846153846 * _BlurScale, 0); 
#if UNITY_SINGLE_PASS_STEREO
        inc.x *= 2.0;
#endif
        o.uv1 = UnityStereoScreenSpaceUVAdjust(v.texcoord - inc, _MainTex_ST);  
        o.uv2 = UnityStereoScreenSpaceUVAdjust(v.texcoord + inc, _MainTex_ST);  
        half2 inc2 = half2(_MainTex_TexelSize.x * 3.2307692308 * _BlurScale, 0);    
#if UNITY_SINGLE_PASS_STEREO
        inc2.x *= 2.0;
#endif
        o.uv3 = UnityStereoScreenSpaceUVAdjust(v.texcoord - inc2, _MainTex_ST);
        o.uv4 = UnityStereoScreenSpaceUVAdjust(v.texcoord + inc2, _MainTex_ST); 
        return o;
    }   
    
    v2fCross vertBlurV(appdata v) {
        v2fCross o;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_TRANSFER_INSTANCE_ID(v, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        o.pos = UnityObjectToClipPos(v.vertex);
        #if UNITY_UV_STARTS_AT_TOP
        if (_MainTex_TexelSize.y < 0) {
            // Texture is inverted WRT the main texture
            v.texcoord.y = 1.0 - v.texcoord.y;
        }
        #endif   
        o.uv = UnityStereoScreenSpaceUVAdjust(v.texcoord, _MainTex_ST);
        half2 inc = half2(0, _MainTex_TexelSize.y * 1.3846153846 * _BlurScale); 
        o.uv1 = UnityStereoScreenSpaceUVAdjust(v.texcoord - inc, _MainTex_ST);  
        o.uv2 = UnityStereoScreenSpaceUVAdjust(v.texcoord + inc, _MainTex_ST);  
        half2 inc2 = half2(0, _MainTex_TexelSize.y * 3.2307692308 * _BlurScale);    
        o.uv3 = UnityStereoScreenSpaceUVAdjust(v.texcoord - inc2, _MainTex_ST); 
        o.uv4 = UnityStereoScreenSpaceUVAdjust(v.texcoord + inc2, _MainTex_ST); 
        return o;
    }
    
        
    half4 fragBlur (v2fCross i): SV_Target {
        UNITY_SETUP_INSTANCE_ID(i);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
        half4 pixel = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv) * 0.2270270270
                    + (UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv1) + UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv2)) * 0.3162162162
                    + (UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv3) + UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.uv4)) * 0.0702702703;
        return pixel;
    }   
 
    
#endif // OVERLAY_FOG

#endif // VOLUMETRIC_FOG_INCLUDED