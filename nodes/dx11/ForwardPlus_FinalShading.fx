#ifndef FINALSHADING
#define FINALSHADING 1
#endif

#ifndef FORWARDPLUS_FXH
#include "forwardplus.fxh"
#endif

#ifndef FINALSHADING_FXH
#include "finalshading.fxh"
#endif


cbuffer cbPerDraw : register(b0)
{
	float4x4 tV: VIEW;
	float4x4 tP: PROJECTION; 
	float4x4 tVP: VIEWPROJECTION;
	bool useForwardPlus;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};
 
int numThreadGroupsX : THREADGROUPSX;;
StructuredBuffer<Light> Lights : LIGHTS;
StructuredBuffer<uint> LightIndexList : LIGHTINDEXLIST;
StructuredBuffer<uint2> LightGrid : LIGHTGRID;
StructuredBuffer<Material> Mat; 

VertexShaderOutput VS_main( AppData IN )
{
	VertexShaderOutput OUT = vs(IN , tW, tV, tVP);
	/*// Clip space
    OUT.position 	= mul(  float4( IN.position, 1.0f ), mul(tW,tVP) );
	// ViewSpace
	float4x4 tWV 	= mul(tW,tV);
    OUT.positionVS 	= mul( float4( IN.position, 1.0f ), tWV ).xyz;
    OUT.tangentVS 	= mul( IN.tangent, 	(float3x3)tWV );
    OUT.binormalVS 	= mul( IN.binormal,	(float3x3)tWV );
    OUT.normalVS 	= mul( IN.normal, 	(float3x3)tWV );
	// Texture coordinate
    OUT.texCoord 	= IN.texCoord;*/ 
	return OUT;
}

[earlydepthstencil]
float4 PS_main( VertexShaderOutput IN ) : SV_TARGET
{
    // Everything is in view space.
    const float4 eyePos = { 0, 0, 0, 1 };
    Material mat = Mat[0];

    float4 diffuse = mat.DiffuseColor;
    if ( mat.HasDiffuseTexture == 1 )
    {
        float4 diffuseTex = DiffuseTexture.Sample( LinearRepeatSampler, IN.texCoord );
        if ( any( diffuse.rgb ) )
        {
            diffuse *= diffuseTex;
        }
        else
        {
            diffuse = diffuseTex;
        }
    }

    // By default, use the alpha from the diffuse component.
    float alpha = diffuse.a;
    if ( mat.HasOpacityTexture == 1)
    {
        // If the material has an opacity texture, use that to override the diffuse alpha.
        alpha = OpacityTexture.Sample( LinearRepeatSampler, IN.texCoord ).r;
    }

    float4 ambient = mat.AmbientColor;
    if ( mat.HasAmbientTexture == 1)
    {
        float4 ambientTex = AmbientTexture.Sample( LinearRepeatSampler, IN.texCoord );
        if ( any( ambient.rgb ) )
        {
            ambient *= ambientTex;
        }
        else
        {
            ambient = ambientTex;
        }
    }
    // Combine the global ambient term.
    ambient *= mat.GlobalAmbient;

    float4 emissive = mat.EmissiveColor;
    if ( mat.HasEmissiveTexture == 1)
    {
        float4 emissiveTex = EmissiveTexture.Sample( LinearRepeatSampler, IN.texCoord );
        if ( any( emissive.rgb ) )
        {
            emissive *= emissiveTex;
        }
        else
        {
            emissive = emissiveTex;
        }
    }

    if ( mat.HasSpecularPowerTexture == 1)
    {
        mat.SpecularPower = SpecularPowerTexture.Sample( LinearRepeatSampler, IN.texCoord ).r * mat.SpecularScale;
    }

    float4 N;

    // Normal mapping
    if ( mat.HasNormalTexture == 1)
    {
        // For scense with normal mapping, I don't have to invert the binormal.
        float3x3 TBN = float3x3( normalize( IN.tangentVS ),
                                 normalize( IN.binormalVS ),
                                 normalize( IN.normalVS ) );

        N = DoNormalMapping( TBN, NormalTexture, LinearRepeatSampler, IN.texCoord );
        //return N;
    }
    // Bump mapping
    else if ( mat.HasBumpTexture == 1)
    {
        // For most scenes using bump mapping, I have to invert the binormal.
        float3x3 TBN = float3x3( normalize( IN.tangentVS ),
                                 normalize( -IN.binormalVS ),
                                 normalize( IN.normalVS ) );

        N = DoBumpMapping( TBN, BumpTexture, LinearRepeatSampler, IN.texCoord, mat.BumpIntensity );
        //return N;
    }
    // Just use the normal from the model.
    else
    {
        N = normalize( float4( IN.normalVS, 0 ) );
        //return N;
    }

    float4 P = float4( IN.positionVS, 1 );
    float4 V = normalize( eyePos - P );

    // Get the index of the current pixel in the light grid.
    uint2 tileIndex = uint2( floor(IN.position.xy / BLOCK_SIZE));
	uint  flatIndex = tileIndex.x + ( tileIndex.y * numThreadGroupsX );

    // Get the start position and offset of the light in the light index list.
    uint startOffset = LightGrid[flatIndex].x;
    uint lightCount  = LightGrid[flatIndex].y;

    LightingResult lit = (LightingResult)0; // DoLighting( Lights, mat, eyePos, P, N );

	if (useForwardPlus)
	{
	    for ( uint i = 0; i < lightCount; i++ )
	    {
	        uint lightIndex = LightIndexList[startOffset + i];
	        Light light = Lights[lightIndex];
	
	        LightingResult result = (LightingResult)0;
	
	        // Skip point and spot lights that are out of range of the point being shaded.
	        if ( light.Type != DIRECTIONAL_LIGHT && length( light.PositionVS - P ) > light.Range ) continue;
	
	        switch ( light.Type )
	        {
	        case DIRECTIONAL_LIGHT:
	        {
	            result = DoDirectionalLight( light, mat, V, P, N );
	        }
	        break;
	        case POINT_LIGHT:
	        {
	            result = DoPointLight( light, mat, V, P, N );
	        }
	        break;
	        case SPOT_LIGHT:
	        {
	            result = DoSpotLight( light, mat, V, P, N );
	        }
	        break;
	        }
	        lit.Diffuse += result.Diffuse;
	        lit.Specular += result.Specular;
	    }	
	} 
	else 
	{
		lit = DoLighting( Lights, mat, eyePos, P, N );
	}
    
    diffuse *= float4( lit.Diffuse.rgb, 1.0f ); // Discard the alpha value from the lighting calculations.

    float4 specular = 0;
    if ( mat.SpecularPower > 1.0f ) // If specular power is too low, don't use it.
    {
        specular = mat.SpecularColor;
        if ( mat.HasSpecularTexture == 1)
        {
            float4 specularTex = SpecularTexture.Sample( LinearRepeatSampler, IN.texCoord );
            if ( any( specular.rgb ) )
            {
                specular *= specularTex;
            }
            else
            {
                specular = specularTex;
            }
        }
        specular *= lit.Specular;
    }
	
    return float4( ( ambient + emissive + diffuse + specular ).rgb, alpha * mat.Opacity );

}

technique11 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS_main() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_main() ) );
	}
}




