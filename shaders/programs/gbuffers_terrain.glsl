
#ifdef VSH

#include "utils/shadowCommon.glsl"
const float eyeBrightnessHalflife = 4.0f;

#define SEPARATE_AO

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#define PI 3.14159265358979323
#include "/shaders.settings"

uniform sampler2D texture;
uniform vec3 sunVec;
uniform vec4 lightCol;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform int blockEntityId;
uniform vec2 texelSize;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int worldTime;

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
attribute vec4 at_tangent; 
in vec3 at_velocity; // vertex offset to previous frame

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float txGlowThreshold;
// -- -- -- -- -- -- -- --

varying vec4 lmtexcoord;
varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 texcoordminmax;
varying vec4 lmcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float sunInfMult;    
varying float sunDot;


varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec4 shadowPos;
varying vec3 shadowOffset;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec2 vTexelSize;
varying vec4 vUVMinMax;

varying vec4 vColor;
varying vec4 vAvgColor;
varying float vColorOnly;
varying float vCrossBlockCull;

varying float vAlphaMult;
varying float vAlphaRemove;

varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying float vDetailBluringMult;
varying float vMultiTexelMap;

varying float vAltTextureMap;

varying float vIsLava;
varying float vLightingMult;
varying float vCdGlow;
varying float vDepthAvgColorInf;

// -- Chocapic13 HighPerformance Toaster --
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}
// -- -- -- -- -- --


void main() {
	vec3 normal = gl_NormalMatrix * gl_Normal;
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	lmtexcoord.xy = gl_MultiTexCoord0.xy;
  vWorldNormal = gl_Normal;
  vAnimFogNormal = gl_NormalMatrix*vec3(1.0,0.0,0.0);
  
  
  // -- -- -- -- -- -- -- --
  
  
	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);

  vLocalPos = gl_Vertex;
  vPos = gl_ProjectionMatrix * gl_Vertex;
	gl_Position = vPos;

  vPos = vec4(position,1.0);
  
	vColor = gl_Color;


  vec4 textureUV = gl_MultiTexCoord0;



  vTexelSize = texelSize;//vec2(1.0/1024.,1.0/1024.);                                   
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	//texcoord = gl_MultiTexCoord0;

  

	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).st;
  texcoordmid=midcoord;
  vec2 texelhalfbound = vTexelSize*16.0;
  texcoordminmax = vec4( midcoord-texelhalfbound, midcoord+texelhalfbound );
  
  
  // Texture Atlas Min/Max UV Range
  vec2 uvRotBase=(texcoord).xy - mc_midTexCoord;
  vec2 uvRotated = uvRotBase;
  uvRotated.x = cos(uvRotBase.x + PI) - sin(uvRotBase.y + PI);
  uvRotated.y = sin(uvRotBase.x + PI) + cos(uvRotBase.y + PI);
  uvRotated += mc_midTexCoord;
  vUVMinMax = vec4(
      min( uvRotated.x, uvRotBase.x ),
      min( uvRotated.y, uvRotBase.y ),
      max( uvRotated.x, uvRotBase.x ),
      max( uvRotated.y, uvRotBase.y )
    );
  
  
  float avgBlend = .3;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(texture, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  /*tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;*/
    
  mixColor = mix( vec3(length(vColor.rgb)), mixColor, step(.1, length(mixColor)) );

  vAvgColor = vec4( mixColor, 1.0);


	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;


	
	vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
	vtexcoordam.pq = abs(texcoordminusmid)*2.0;
	vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
	vtexcoord = sign(texcoordminusmid)*0.5+0.5;
  
  
  vNormal = normalize(normal);
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  sunDot = dot( vNormal, normalize(sunPosition) );
  sunDot = dot( vNormal, normalize(localSunPos) );
  sunDot = dot( (gbufferModelViewInverse*gl_Vertex).xyz, normalize(vec3(1.0,0.,0.) ));



  // -- -- -- -- -- -- -- --


  // TODO : Is this needed? Left over testing other's code
	float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  #ifdef SEPARATE_AO
	lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU*gl_Color.a)+0.5;
  #else
  lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  #endif

	gl_Position = toClipSpace3(position);
	float diffuseSun = clamp( ( dot(normal,sunVec)*.6+.4) * lightCol.a, 0.0,1.0 );


  // -- -- -- -- -- -- -- --
  
  // Shadow Prep
  position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
  shadowPos.xyz = mat3(shadowModelView) * position.xyz + shadowModelView[3].xyz;
  vec3 shadowProjDiag = diagonal3(shadowProjection);
  shadowPos.xyz = shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz;


  // -- -- -- -- -- -- -- --
  
  
  vAlphaMult=1.0;
  vColorOnly=0.0;
  vIsLava=0.0;
  vCdGlow=0.0;
  vCrossBlockCull=0.5;

  blockFogInfluence = 1.0;
  if (mc_Entity.x == 803){
    blockFogInfluence = 1.;
  }
  
  txGlowThreshold = 1.0; // Off
  if (mc_Entity.x == 804){
    txGlowThreshold = 1.00;//.7;
    blockFogInfluence = 1.0;
  }

  /*
  // Single plane cross blocks;
  //   Grass, flowers, etc.
  if (mc_Entity.x == 801){
    //vCrossBlockCull = abs(dot(vec3(vWorldNormal.x, 0.0, vWorldNormal.z),normalize(vec3(vPos.x, 0.0, vPos.z)) ));
    vCrossBlockCull = abs(dot(vec3(vWorldNormal.x, 0.0, vWorldNormal.z),normalize(vec3(1.0, 0.0, 1.0)) ));
    //vCrossBlockCull = abs( dot( normalize(vLocalPos.xyz), normalize(vec3(1.0, 0.0, 1.0)) ) );
    vCrossBlockCull = abs( dot( normalize(vec3(vWorldNormal.x, 0.0, vWorldNormal.z)), normalize(vec3(vLocalPos.x, 0.0, vLocalPos.z)) ) );
    //vCrossBlockCull =  dot( normalize(vLocalPos.xyz), normalize(vec3(1.0, 0.0, 1.0)) )*.5+.5;
    
    //vAlphaMult=clamp( (vCrossBlockCull+.5)*10.0, 0.0, 1.0 );
    //vAlphaMult=step(.5, vCrossBlockCull);
    
    float alphaStep = abs(vCrossBlockCull-.5)-.2;

    vCrossBlockCull=step( .0, alphaStep );
    //vCrossBlockCull=step( .5, vCrossBlockCull );
    vAlphaMult=vCrossBlockCull;
  }
  */
  
  // Leaves
  vAlphaRemove = 0.0;
  if (mc_Entity.x == 810 && SolidLeaves ){
      vColorOnly=.001;
      vAltTextureMap=1.0;
      vAvgColor=vColor*.5;
    vAlphaRemove = 1.0;
  }


  // General Alt Texture Reads
  vAltTextureMap=1.0;
  vec2 prevTexcoord = texcoord.zw;
  texcoord.zw = texcoord.st;
  vDepthAvgColorInf = 1.0;

  
  // TODO : Remove all the daggon ifs somehow
  
  if( mc_Entity.x == 901 || mc_Entity.x == 801 || mc_Entity.x == 811 || mc_Entity.x == 8013 ){
    texcoord.zw = texcoord.st;
    vColorOnly=.001;
    //vColor.rgb=vec3(1.0);
    vAltTextureMap = 0.0;
    vAvgColor*=vColor;
    vDepthAvgColorInf=.3;
  }
  if( mc_Entity.x == 801 || mc_Entity.x == 8011 || mc_Entity.x == 8012 || mc_Entity.x == 8013 ){
    vDepthAvgColorInf =  0.0;
  }
  if( mc_Entity.x == 907 ){
    vDepthAvgColorInf =  0.0;
    vAltTextureMap = 1.0;
    vColorOnly=.001;
  }
  if( mc_Entity.x == 603 ){
    //vColor = vec4(1.0,0.0,0.0,1.0);
    //vAvgColor = vec4(1.0,0.0,0.0,1.0);
    //vColorOnly=.1;
  }
  
  
  
  // Lava
  if( mc_Entity.x == 701 ){
    vIsLava=.8;
#ifdef NETHER
    vCdGlow=.1;
#else
     vCdGlow=.05;
#endif
    //vColorOnly=1.10;
    //vColorOnly=1.30;
    vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  // Flowing Lava
  if( mc_Entity.x == 702 ){
    vIsLava=0.9;
#ifdef NETHER
    //vCdGlow=.1;
#else
    vCdGlow=.05;
#endif
    //vColorOnly=0.30;
    //vColorOnly=1.30;
    vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  
  // Fire / Soul Fire
  if( mc_Entity.x == 707 ){
#ifdef NETHER
    vCdGlow=0.15;
#endif
    //vAvgColor = vec4( .8, .6, .0, 1.0 );
    
    vDepthAvgColorInf =  0.0;
  }
  // End Rod, Soul Lantern, Glowstone, Redstone Lamp, Sea Lantern, Shroomlight, Magma Block
  if( mc_Entity.x == 805 ){
    vCdGlow=0.02;
#ifdef NETHER
    vCdGlow=0.1;
#endif
    vDepthAvgColorInf = 0.20;
  }
  

  // Amethyst Block
  vLightingMult=1.0;
  if (mc_Entity.x == 909){
    texcoord.zw = texcoord.st;
    vColorOnly=0.50;
    vLightingMult = 1.2;
    vAvgColor.rgb = vec3(.35,.15,.7);
    //vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .7 );
  }
  // Amethyst Clusters
  if (mc_Entity.x == 910){
    texcoord.zw = texcoord.st;
    //vColorOnly=0.100;
    vLightingMult = 1.2;
    //vColor.rgb = vAvgColor.rgb;//mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  

  //vColor.a = diffuseSun * gl_MultiTexCoord1.y;
  sunInfMult = diffuseSun * gl_MultiTexCoord1.y;
//vColor.a=1.0;//
                                                                              
  //vColor = mix( gl_Color, vColor, eyeBrightnessSmooth.y/240.0);
  //vColor = gl_Color;



}

#endif




/* */
/* */
/* */



#ifdef FSH


/* RENDERTARGETS: 0,1,2,7,6,9 */

#define gbuffers_terrain
/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"



uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D colortex5; // Minecraft Vanilla Glow Atlas
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int fogMode;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float BiomeTemp;
uniform int moonPhase;
uniform float nightVision;
uniform ivec2 atlasSize; 

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform sampler2DShadow shadow;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform int shadowQuality;

uniform vec4 lightCol;
uniform vec2 texelSize;

uniform int worldTime;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;


// To Implement
//uniform float wetness;  //rainStrength smoothed with wetnessHalfLife or drynessHalfLife
//uniform int fogMode;
//uniform float fogStart;
//uniform float fogEnd;
//uniform int fogShape;
//uniform float fogDensity;
//uniform int heldBlockLightValue;
//uniform int heldBlockLightValue2;
uniform float rainStrength;


uniform vec3 upPosition;

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float txGlowThreshold;
// -- -- -- -- -- -- -- --

varying vec4 lmtexcoord;
varying vec4 vColor;
varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 texcoordminmax;
varying vec4 lmcoord;
varying vec2 vTexelSize;
varying vec4 vUVMinMax;

varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float sunInfMult;
varying float sunDot;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec4 shadowPos;
varying vec3 shadowOffset;
varying float vAlphaMult;
varying float vAlphaRemove;
varying float vAltTextureMap;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;


varying vec4 vAvgColor;
varying float vColorOnly;
varying float vCrossBlockCull;

varying float vIsLava;
varying float vLightingMult;
varying float vCdGlow;
varying float vDepthAvgColorInf;


void main() {
  
    vec2 tuv = texcoord.st;
    if( vAltTextureMap > .5 ){
      tuv = texcoord.zw;
    }
    vec2 luv = lmcoord.st;

    float glowInf = texture2D(colortex5, tuv).x;
    glowInf *= glowInf;
    vec3 glowCd = vec3(0,0,0);

    float isLava = vIsLava;
    vec4 avgShading = vAvgColor;

    // -- -- -- -- -- -- --
    
    vec4 txCd;
    // TODO : There's gotta be a better way to do this...
    if( DetailBluring > 0 ){
        txCd = diffuseSample( texture, tuv, vtexcoordam, vTexelSize-.0005, DetailBluring*2.0 );
        //txCd = diffuseNoLimit( texture, tuv, vTexelSize*vec2(3.75,2.1)*DetailBluring );
    }else{
      txCd = texture2D(texture, tuv);
    }

    txCd.rgb = mix(txCd.rgb, vColor.rgb, vAlphaRemove);
    txCd.a = mix(txCd.a, 1.0, vAlphaRemove);
    if (txCd.a * vAlphaMult < .2){
      discard;
    }
    
    
    
    // Screen Space UVing and Depth
    vec2 screenSpace = (vPos.xy/vPos.z);
    float screenDewarp = length(screenSpace)*0.7071067811865475; //  1 / length(vec2(1.0,1.0))
    //float depth = min(1.0, max(0.0, gl_FragCoord.w-screenDewarp));
    float depth = min(1.0, max(0.0, gl_FragCoord.w+glowInf));
    float depthBias = biasToOne(depth, 4.5);
    float depthDetailing = clamp(1.195-depthBias*1.25, 0.0, 1.0);

    
    

  // -- -- -- -- -- -- -- --
  // Modified shadow lookup from Chocapic13's HighPerformance Toaster
  //  (I'm still learning this shadow stuffs)
  //
  float shadowDist = 0.0;
  float diffuseSun = 1.0;
  
#ifdef OVERWORLD

  float distort = calcDistort(shadowPos.xy);
  vec2 spCoord = shadowPos.xy / distort;
  if (abs(spCoord.x) < 1.0-1.5/shadowMapResolution && abs(spCoord.y) < 1.0-1.5/shadowMapResolution) {
    float diffthresh = 0.0006*shadowDistance/45.;
    diffthresh = 0.0004*1024./shadowMapResolution*shadowDistance/45.*distort/diffuseSun;

    vec3 projectedShadowPosition = vec3(spCoord, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
    
    float shadowAvg=shadow2D(shadow, projectedShadowPosition).x;
    
    
#if ShadowSampleCount > 0

    // Modded for multi sampling the shadow
    // TODO : Functionize this rolled up for loop dooky
    
    vec2 posOffset;
    
    for( int x=0; x<boxSamplesCount; ++x){
      posOffset = boxSamples[x]*.001;
      projectedShadowPosition = vec3(spCoord+posOffset, shadowPos.z-posOffset.x*.2) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
    
      shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .15);
    }
    
#if ShadowSampleCount > 1

    for( int x=0; x<boxSamplesCount; ++x){
      posOffset = boxSamples[x]*.002;
      projectedShadowPosition = vec3(spCoord+posOffset, shadowPos.z-posOffset.x*.5) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
    
      shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .1);
    }
    
#endif

#endif
    
    float sunMoonShadowInf = clamp( (abs(dot(sunVecNorm, vNormal))-.04)*2.0, 0.0, 1.0 );
    //float sunMoonShadowInf = min(1.0, max(0.0, abs(dot(sunVecNorm, vNormal))-.5)*1.0);
    float shadowDepthInf = clamp( (depth*40.0), 0.0, 1.0 );
    diffuseSun *= mix( 1.0, shadowAvg, sunMoonShadowInf * shadowDepthInf );
  }
  
#endif

  // -- -- -- -- -- -- -- --


  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
    diffuseSun = smoothstep(.0,.65,diffuseSun); 
    // Mute Shadows during Rain
    diffuseSun = mix( diffuseSun*.6+.6, 1.0, rainStrength);
    
    //float blockShading = max( diffuseSun, (sin( vColor.a*PI*.5 )*.5+.5) );
    float blockShading = diffuseSun * (sin( vColor.a*PI*.5 )*.5+.5);
    
		vec3 lightmapcd = texture2D(gaux1,lmtexcoord.zw*vTexelSize).xyz;// *.5+.5;
		vec3 diffuseLight = mix(lightCol.rgb*.5+.5, vec3(1,1,1),.7) ;
		diffuseLight *= max(lightmapcd, vec3(blockShading) ) ;
    
    
    

    
    vec4 lightBaseCd = texture2D(lightmap, luv);
    vec3 lightCd = lightBaseCd.rgb;//*vLightingMult; 
    
    vec4 blockLumVal =  vec4(1,1,1,1);
    
#ifdef OVERWORLD
    blockLumVal =  vec4(lightCd,1.0);
#endif

#ifdef NETHER
    //blockLumVal =  vec4( mix((fogColor*.4+.4), lightCd, depth), 1.0);
    //blockLumVal =  vec4( lightCd, 1.0);
    blockLumVal =  vec4( (fogColor*.4+.4), 1.0);
#endif

    float lightLuma = luma(blockLumVal.rgb);
    
    // -- -- -- -- -- -- --
    // -- Set base color -- --
    // -- -- -- -- -- -- -- -- --
    vec4 outCd = vec4(txCd.rgb,1.0) * vec4(vColor.rgb,1.0);
    //outCd = mix( vec4(outCd.rgb,1.0),  vec4(vColor.rgb,1.0), vColorOnly*depthDetailing);
    outCd = mix( vec4(outCd.rgb,1.0),  vec4(avgShading.rgb,1.0), depthDetailing*vDepthAvgColorInf);
    outCd = mix( outCd,  vec4(avgShading.rgb,1.0), vIsLava);

    float dotToCam = dot(vNormal,normalize(vec3(screenSpace*(1.0-depthBias),1.0)));
    outCd*=mix(1.0, dotToCam*.5+.5, vIsLava);

    
    // -- -- -- -- -- -- -- --
    // -- Sun/Moon Lighting -- --
    // -- -- -- -- -- -- -- -- -- --
    float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.0,.91,1.0)),vNormal);
    float surfaceShading = 1.0-abs(toCamNormalDot);

    float skyBrightnessMult = 1.0;
    
    
    // -- -- -- -- -- -- --
    // -- Fog Coloring - -- --
    // -- -- -- -- -- -- -- -- --
    vec3 toFogColor = fogColor*lightmapcd;

#ifdef OVERWORLD
    
    float sunPhaseMult = 1.0-max(0.0,dot( sunVecNorm, upVecNorm)*.8+.2);
    sunPhaseMult = 1.0-(sunPhaseMult*sunPhaseMult*sunPhaseMult);
    
    skyBrightnessMult=eyeBrightnessSmooth.y*0.004166666666666666;//  1.0/240.0
    float moonPhaseMult = (1+mod(moonPhase+3,8))*.25;
    moonPhaseMult = min(1.0,moonPhaseMult) - max(0.0, moonPhaseMult-1.0);
    moonPhaseMult = (moonPhaseMult*.4+.1);
    
    diffuseLight *= mix( moonPhaseMult, 1.0, clamp(dayNight*2.0+.5 + (1-skyBrightnessMult), 0.0, 1.0) );

    surfaceShading *= mix( moonPhaseMult, dot(sunVecNorm,vNormal), dayNight*.5+.5 );
    surfaceShading *= sunPhaseMult;
    surfaceShading *= 1.0-(rainStrength*.9+.1);
    
    toFogColor*=lightCol.rgb;
    
#endif
    
    // -- -- -- -- -- -- --
    // -- Night Vision - -- --
    // -- -- -- -- -- -- -- -- --
    toFogColor = mix(toFogColor* skyBrightnessMult, vec3(1.0), nightVision);
    
    
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    // -- 'Specular' Roll-Off; Radial Highlights -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    
    depthDetailing = max(0.0, min(1.0,(1.0-(depthBias+(vCdGlow*5.0)))*.450) );
    surfaceShading = 1.0-(1.0-surfaceShading)*.4;
    outCd.rgb += outCd.rgb * depthBias * surfaceShading * depthDetailing * .5; // *fogColor; // -.2;


    // -- -- -- -- -- -- 

#ifdef NETHER
    // TODO : Remove the needlessness of this!
    //          Since I'm mixing saturation and value,
    //            This seems a bit overkill to convert rgb -> hsv -> rgb
    //          Multiply the color vector evenly
    outCd.rgb = rgb2hsv(outCd.rgb);
    
    // Reds drive a stronger color tone in blocks
    float colorRed = outCd.r;
    outCd.g = mix( outCd.g, min(1.0,outCd.g*1.3), min(1.0, abs(1.0-colorRed-.5)*20.0) );
    outCd.b = mix( outCd.b, min(1.0,outCd.b*1.3), min(1.0, abs(1.0-colorRed-.5)*20.0) );

    outCd.rgb = hsv2rgb(outCd.rgb);
#endif


    // -- -- -- -- -- -- 


    // -- -- -- -- -- -- -- -- --
    // -- Lighting influence - -- --
    // -- -- -- -- -- -- -- -- -- -- --
    outCd.rgb *=  lightLuma + glowInf + vCdGlow;


    // -- -- -- -- -- -- --

    // TODO : Move whats possible to vert
    float distMix = min(1.0,gl_FragCoord.w);
    float waterLavaSnow = float(isEyeInWater);
    if( isEyeInWater == 1 ){ // Water
      float smoothDepth=min(1.0, smoothstep(.01,.1,depth));
      //outCd.rgb *=  1.0+lightLuma+glowInf;
      outCd.rgb *=  1.0+lightLuma*.5;//+.5;
    }else if( isEyeInWater > 1 ){ // Lava
      depthBias = depthBias*.1; // depth;
      depth *= .5;
      
      outCd.rgb = mix( outCd.rgb, toFogColor, (1.0-distMix*.01) );
    //}else if( isEyeInWater == 3 ){ // Snow
      //outCd.rgb = mix( outCd.rgb, toFogColor, (1.0-distMix*.1) );
    }else{
      outCd.rgb = mix( toFogColor, outCd.rgb, min(1.0,depth*80.0)*.8+.2+glowInf );
    }

    
    
// -- -- -- -- -- -- -- -- -- -- 
// End Logic; Animated Fog  - -- --
// -- -- -- -- -- -- -- -- -- -- -- --

// TODO : MOVE TO POST PROCESSING ... ya dingus

#ifdef THE_END
      float depthEnd = min(1.0, gl_FragCoord.w*8.0-screenDewarp*.15);
      depthEnd = 1.0-(1.0-depthEnd)*(1.0-depthEnd);
    
      float lightMax = max( lightCd.r, max( lightCd.g, lightCd.b ) );
    
      
      
      vec3 endFogCd = vec3(.75,.5,.75);
      
      float timeOffset = (worldTime*0.00004166666)*90.0;
      vec3 worldPos = fract(abs(cameraPosition+vLocalPos.xyz)*vec3(.09,.06,.05));
      worldPos = fract( worldPos+texture2D( noisetex, worldPos.xz).rgb );

      vec3 noiseX = texture2D( noisetex, worldPos.xy + (timeOffset*vec2(1.,.5))).rgb;
      vec3 noiseZ = texture2D( noisetex, fract(worldPos.zy*1.5+noiseX.rg + vec2(timeOffset) )).rgb;
      
      float noiseInf = min(1.0, (depthEnd+max(0.0,lightMax-.4+glowInf*.8))*.8+.1 );
      
      outCd.rgb *= mix(  (noiseZ*endFogCd*lightCd), vec3(1.0), noiseInf );
#endif
    
    /*
    // World Space Position influenced animated Noise
    //float timeOffset = (worldTime*0.00004166666)*80.0;
    vec3 worldPos = fract(abs(cameraPosition+vLocalPos.xyz)*.08);
    worldPos = fract( worldPos+texture2D( noisetex, worldPos.xz).rgb );
    vec3 noiseInit = texture2D( noisetex, tuv).rgb;
    //vec3 noiseAnim = texture2D( softnoisetex, fract(tuv+noiseInit.rg + noiseInit.br)).rgb;

    vec3 noiseX = texture2D( noisetex, worldPos.xy).rgb;
    vec3 noiseZ = texture2D( noisetex, fract(worldPos.zy+noiseX.rg + vec2(timeOffset) )).rgb;
    vec3 noiseY = texture2D( noisetex, fract(worldPos.xz+noiseZ.br + vec2(timeOffset*.1) )).rgb;
    vec3 noiseCd = mix( noiseX, noiseZ, abs(vWorldNormal.x));
    noiseCd = mix( noiseCd, noiseY, abs(vWorldNormal.y));
    */
    
    //if( glowMultVertColor > 0.0 ){
      //float outCdMin = min(outCd.r, min( outCd.g, outCd.b ) );
      float outCdMin = max(outCd.r, max( outCd.g, outCd.b ) );
      //float outCdMin = max(txCd.r, max( txCd.g, txCd.b ) );
      glowCd = addToGlowPass(glowCd, mix(txCd.rgb,outCd.rgb,.5)*step(txGlowThreshold,outCdMin)*(depth*.5+.5));
    //}
    
    
    
    // Texcoord fit to block
    //vec2 localUV = vec2(0.0);
    //localUV.x = (tuv.x-texcoordminmax.x) / (texcoordminmax.z-texcoordminmax.x);
    //localUV.y = (tuv.y-texcoordminmax.y) / (texcoordminmax.w-texcoordminmax.y);
    
    

#ifdef NETHER
    //outCd.rgb *= mix( outCd.rgb+outCd.rgb*vec3(1.6,1.3,1.2), vec3(1.0), (depthBias)*.4+.4);
    outCd.rgb = mix( fogColor*(lightCd+.5), outCd.rgb*lightCd, smoothstep(.015, .35, depthBias+glowInf*.5));
    outCd.rgb *= mix(1.0, toCamNormalDot, depth*.7+.3);
#else
    outCd.rgb *= mix(1.0, toCamNormalDot*.5+.5, depth*.7+.3);
#endif


    
    //outCd.rgb = mix( outCd.rgb,vec3( txCd.a,txCd.a,txCd.a), step(screenSpace.y,0.0));
    //outCd.rgb = mix( outCd.rgb, (texture2D(texture, tuv) * blockLumVal * vec4(vColor.rgb,1.0)).rgb, step(screenSpace.x,0.0));
    
    //blockShading = max( blockShading, lightLuma );// lightLuma is lightCd
    
    
#ifdef OVERWORLD
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
    // Biome & Snow Glow when in a Cold Biome - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    float frozenSnowGlow = 1.0-smoothstep(.0,.2,BiomeTemp);
    glowCd = addToGlowPass(glowCd, outCd.rgb*frozenSnowGlow*.3*(1.0-sunPhaseMult)*max(0.06,-dayNight)*max(0.0,(1.0-depth*3.0)));
    //float cdBrightness = min(1.0,max(0.0,dot(txCd.rgb,vec3(1.0))));
    //cdBrightness *= cdBrightness;
    //outCd.rgb *= 1.0+cdBrightness*frozenSnowGlow*3.5*max(0.06,-dayNight)*(1.0-rainStrength);
    outCd.rgb *= 1.0+frozenSnowGlow*max(0.06,-dayNight)*(1.0-rainStrength)*skyBrightnessMult;
    outCd.rgb *= 1.0-rainStrength*.35*skyBrightnessMult*(1.0-vIsLava);
    
    
    // -- -- -- -- -- -- -- -- -- -- -- 
    // Outdoors vs Caving Lighting - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- --
    // Brighten blocks when going spelunking
    // TODO: Promote control to Shader Options
    float skyBrightMultFit = 1.1-skyBrightnessMult*.1*(1.0-frozenSnowGlow);
    outCd.rgb *= skyBrightMultFit;
    outCd.rgb*=mix(vec3(1.0), diffuseLight, skyBrightnessMult*sunPhaseMult);
#endif
    
    
    glowInf += (luma(outCd.rgb)+vIsLava)*vCdGlow;
    
    glowCd += outCd.rgb+(outCd.rgb+.1)*glowInf;


    vec3 glowHSV = rgb2hsv(glowCd);
    glowHSV.z *= glowInf * (depthBias*.5+.2) * GlowBrightness ;// * lightLuma;


#ifdef NETHER
    outCd.rgb += outCd.rgb*lightCd*min(1.0,vIsLava+glowInf);
#else
    glowHSV.z *= .7+vIsLava*.5;
#endif

    outCd.rgb*=1.0+glowHSV.z;


    // -- -- -- -- -- -- -- -- -- -- 
    // -- Lava & Powda Snow Fog - -- --
    // -- -- -- -- -- -- -- -- -- -- -- --
    float lavaSnowFogInf = 1.0-min(1.0, max(0.0,waterLavaSnow-1.0) );
    glowHSV.z *= lavaSnowFogInf;
    outCd.rgb = mix( fogColor.rgb, outCd.rgb, lavaSnowFogInf);

    
    // -- -- -- -- -- -- -- -- -- -- -- -- --
    // -- Texture Overides from Settings - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    if( GreyWorld ){
      float ssLength = length(screenSpace);
      ssLength *= ssLength * ssLength;
      outCd.rgb = mix( vec3(lightLuma), lightCd, ssLength );
    }
    
    float outDepth = min(.9999,gl_FragCoord.w);
    float outEffectGlow = 0.0;
    //outCd = textureOffset( texture, tuv, ivec2(1,2) );
    /*
    vec4 cdGatherRed = textureGather( texture, tuv, 0 );
    vec4 cdGatherGreen = textureGather( texture, tuv, 1 );
    vec4 cdGatherBlue = textureGather( texture, tuv, 2 );
    outCd.r = ( cdGatherRed.x + cdGatherRed.y + cdGatherRed.z + cdGatherRed.w ) * .25;
    outCd.g = ( cdGatherGreen.x + cdGatherGreen.y + cdGatherGreen.z + cdGatherGreen.w ) * .25;
    outCd.b = ( cdGatherBlue.x + cdGatherBlue.y + cdGatherBlue.z + cdGatherBlue.w ) * .25;
    outCd.a = 1.0;
    */
    //outCd.rgb = vec3( vUVMinMax.xy,0.0);
    //outCd.r = (texcoord.x-vUVMinMax.x) / (vUVMinMax.z-vUVMinMax.x);
    //outCd.g = (texcoord.y-vUVMinMax.y) / (vUVMinMax.w-vUVMinMax.y);
    //outCd.rg = abs(vUVMinMax.xy);
    //outCd.rg = localUV;
    //outCd.rgb = vec3(step(localUV.x, 0.0));
    //outCd.rg = tuv;
    
    //outCd.rgb=vec3(vCrossBlockCull);
    //outCd.rgb=normalize(vLocalPos.xyz);
    outCd.a*=vAlphaMult;
    
    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(outDepth, outEffectGlow, 0.0, 1.0);
    gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
    // [ Sun/Moon Strength, Light Map, Spectral Glow ]
    gl_FragData[3] = vec4(vec3(blockShading, lightBaseCd.r, 0.0), 1.0);
    gl_FragData[4] = vec4( glowHSV, 1.0);
    gl_FragData[5] = vec4( 0.0);

	//}
}


#endif
