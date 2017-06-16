//@author: Johannes Schmidt || Kopffarben GbR
//@help: LightHelper
//@tags: forwardPlus
//@credits: Jeremiah van Oosten

#ifndef FORWARDPLUS_FXH
#include "forwardplus.fxh"
#endif

StructuredBuffer<Light> Lights : LIGHTS;
SamplerState g_samLinear : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};


cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tW : WORLD;
	float alpha;
};


struct VS_IN
{
	uint ii : SV_InstanceID;
	float4 PosO : POSITION;
	float2 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;	
	float4 Color: TEXCOORD0;
    float2 TexCd: TEXCOORD1;
	
};

vs2ps VS(VS_IN input)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
	Light light = Lights[input.ii];
	
	float4 Pos = (input.PosO * float4(light.Range,light.Range,light.Range,1) ) + light.PositionWS; 
    Out.PosWVP  = mul(Pos ,mul(tW,tVP));
	Out.Color = light.Color;
	Out.Color.w *= alpha;
    Out.TexCd = input.TexCd;
    return Out;
}




float4 PS_Tex(vs2ps In): SV_Target
{
     
    return In.Color;
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Tex() ) );
	}
}




