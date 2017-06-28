//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

Texture2D TransparentsTexture : register(t0);
Texture2D OpacityTexture : register(t1);

SamplerState s0 <bool visible=false;string uiname="Sampler";> {Filter=MIN_MAG_MIP_LINEAR;AddressU=CLAMP;AddressV=CLAMP;};

 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
};


cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd: TEXCOORD0;
};

vs2ps VS(VS_IN input)
{
    vs2ps Out = (vs2ps)0;
    Out.PosWVP  = mul(input.PosO,mul(tW,tVP));
    Out.TexCd = input.TexCd;
    return Out;
}




float4 PS(vs2ps In): SV_Target
{
	 
    float4 transparents = TransparentsTexture.Sample(s0,In.TexCd.xy);
    float  opacity 		= OpacityTexture.Sample(s0,In.TexCd.xy).x;
	
	//return opacity;
    return float4(transparents.rgb / max(transparents.a, 1e-5), opacity);
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}




