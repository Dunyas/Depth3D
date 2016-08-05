 ////----------------//
 ///**SuperDepth3D**///
 //----------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Depth Map Based 3D post-process shader v1.7.2 L & R Eye																															*//
 //* For Reshade 3.0																																								*//
 //* --------------------------																																						*//
 //* This work is licensed under a Creative Commons Attribution 3.0 Unported License.																								*//
 //* So you are free to share, modify and adapt it for your needs, and even use it for commercial use.																				*//
 //* I would also love to hear about a project you are using it with.																												*//
 //* https://creativecommons.org/licenses/by/3.0/us/																																*//
 //*																																												*//
 //* Have fun,																																										*//
 //* Jose Negrete AKA BlueSkyDefender																																				*//
 //*																																												*//
 //* http://reshade.me/forum/shader-presentation/2128-sidebyside-3d-depth-map-based-stereoscopic-shader																				*//	
 //* ---------------------------------																																				*//
 //*																																												*//
 //* Original work was based on Shader Based on forum user 04348 and be located here http://reshade.me/forum/shader-presentation/1594-3d-anaglyph-red-cyan-shader-wip#15236			*//
 //*																																												*//
 //* 																																												*//
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform int AltDepthMap <
	ui_type = "combo";
	ui_items = "Depth Map 0\0Depth Map 1\0Depth Map 2\0Depth Map 3\0Depth Map 4\0Depth Map 5\0Depth Map 6\0Depth Map 7\0Depth Map 8\0Depth Map 9\0Depth Map 10\0Depth Map 11\0Depth Map 12\0Depth Map 13\0Depth Map 14\0Depth Map 15\0Depth Map 16\0Depth Map 17\0Depth Map 18\0Depth Map 19\0Depth Map 20\0Depth Map 21\0Depth Map 22\0Depth Map 23\0Depth Map 24\0Depth Map 25\0";
	ui_label = "Alternate Depth Map";
	ui_tooltip = "Alternate Depth Map for different Games. Read the ReadMeDepth3d.txt, for setting. Each game May and can use a diffrent AltDepthMap.";
> = 0;

uniform int Depth <
	ui_type = "drag";
	ui_min = 0; ui_max = 25;
	ui_label = "Depth Slider";
	ui_tooltip = "Determines the amount of Image Warping and Separation between both eyes.";
> = 10;

uniform int Perspective <
	ui_type = "drag";
	ui_min = -100; ui_max = 100;
	ui_label = "Perspective Slider";
	ui_tooltip = "Determines the perspective point.";
> = 0;

uniform int WA <
	ui_type = "drag";
	ui_min = -25; ui_max = 25;
	ui_label = "Warp Adjust";
	ui_tooltip = "Adjust the warp in both eyes.";
> = 0;

uniform bool DepthFlip <
	ui_label = "Depth Flip";
	ui_tooltip = "Depth Flip if the depth map is Upside Down.";
> = false;

uniform bool DepthMap <
	ui_label = "Depth Map View";
	ui_tooltip = "Display the Depth Map. Use This to Work on your Own Depth Map for your game.";
> = false;

uniform int CustomDM <
	ui_type = "combo";
	ui_items = "Custom Off\0Custom One +\0Custom One -\0Custom Two +\0Custom Two -\0Custom Three +\0Custom Three -\0Custom Four +\0Custom Four -\0Custom Five +\0Custom Five -\0Custom Six +\0Custom Six -\0";
	ui_label = "Custom Depth Map";
	ui_tooltip = "Adjust your own Custom Depth Map.";
> = 0;

uniform float Far <
	ui_type = "drag";
	ui_min = 0; ui_max = 5;
	ui_label = "Far";
	ui_tooltip = "Far Depth Map Adjustment.";
> = 1.5;
 
 uniform float Near <
	ui_type = "drag";
	ui_min = 0; ui_max = 5;
	ui_label = "Near";
	ui_tooltip = "Near Depth Map Adjustment.";
> = 1.5;

uniform bool BD <
	ui_label = "Barrel Distortion";
	ui_tooltip = "Barrel Distortion for HMD type Displays.";
> = false;

uniform float Hsquish <
	ui_type = "drag";
	ui_min = 1; ui_max = 2;
	ui_label = "Horizontal Squish";
	ui_tooltip = "Horizontal squish cubic distortion value. Default is 1.050.";
> = 1.050;

uniform float K <
	ui_type = "drag";
	ui_min = -25; ui_max = 25;
	ui_label = "Lens Distortion";
	ui_tooltip = "Lens distortion coefficient. Default is -0.15.";
> = -0.15;

uniform float KCube <
	ui_type = "drag";
	ui_min = -25; ui_max = 25;
	ui_label = "Cubic Distortion";
	ui_tooltip = "Cubic distortion value. Default is 0.5.";
> = 0.5;

uniform bool AltRender <
	ui_label = "Alternate Render";
	ui_tooltip = "Alternate Render Mode is a different way of warping the screen.";
> = true; 

/////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
//#include "ReShade.fxh"

#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

	
texture texCL  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F;}; 
texture texCR  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F;}; 
texture texCC  { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F;}; 

texture DepthBufferTex : DEPTH;
texture BackBufferTex : COLOR;

sampler BackBuffer 
	{ 
		Texture = BackBufferTex; 
	};

sampler DepthBuffer 
	{ 
		Texture = DepthBufferTex; 
	};

sampler SamplerCL
	{
		Texture = texCL;
		AddressU = BORDER;
		AddressV = BORDER;
		AddressW = BORDER;
		MipFilter = Linear; 
		MinFilter = Linear; 
		MagFilter = Linear;
	};
	
sampler SamplerCR
	{
		Texture = texCR;
		AddressU = BORDER;
		AddressV = BORDER;
		AddressW = BORDER;
		MipFilter = Linear; 
		MinFilter = Linear; 
		MagFilter = Linear;
	};
	
sampler2D SamplerCC
	{
		Texture = texCC;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = CLAMP;
		AddressV = CLAMP;
		AddressW = CLAMP;
	};
	
//Right Eye Depth Map Information	
float SbSdepth (float2 texcoord) 	
{

	 float4 color = tex2D(SamplerCC, texcoord);

			if (DepthFlip)
			texcoord.y =  1 - texcoord.y;
	
	float4 depth = tex2D(DepthBuffer, float2(texcoord.x, texcoord.y));
		
	if (CustomDM == 0)
	{		
		//Alien Isolation
		if (AltDepthMap == 0)
		{
		float cF = 0.9125;
		float cN = 0.9125;
		depth = 1 - (cF) / (cF - depth * ((1 - cN) / (cF - cN * depth)) * (cF - 1));
		}
		
		//Batman Games
		if (AltDepthMap == 1)
		{
		float cF = 5;
		float cN = 0;
		depth = (cN - depth * cN) + (depth*cF);
		}
		
		//Quake 2 XP
		if (AltDepthMap == 2)
		{
		float cF  = 0.01;
		float cN = 0;
		depth = 1 - (cF * 1/depth + cN);
		}
		
		//The Evil Within
		if (AltDepthMap == 3)
		{
		float cF = 1.5;
		float cN = 0;
		depth = (cN - depth * cN) + (depth*cF);
		}
		
		//Sleeping Dogs:  DE
		if (AltDepthMap == 4)
		{
		float zF = 1.0;
		float zN = 0.025;
		depth = 1 - (zF * zN / (zN + depth * (zF - zN)) + pow(abs(depth*depth),1.0));
		}
		
		//COD:AW
		if (AltDepthMap == 5)
		{
		float cF  = 0.00001;
		float cN = 0;
		depth = (cF * 1/depth + cN);
		}
		
		//Lords of the Fallen
		if (AltDepthMap == 6)
		{
		float cF  = 1.027;
		float cN = 0;
		depth = 1 - (1 - cF) / (cN - cF * depth); 
		}
		
		//Shadow Warrior
		if (AltDepthMap == 7)
		{
		float cF = 10;
		float cN = 0;
		depth = (cN - depth * cN) + (depth*cF);
		}
		
		//Rage
		if (AltDepthMap == 8)
		{
		float LinLog = 0.005;
		depth = (1 - (LinLog) / (LinLog - depth * 1.5 * (LinLog -  0.05)))+(pow(abs(depth*depth),3.5));
		}	
		
		//Assassin's Creed Unity
		if (AltDepthMap == 9)
		{
		float cF = 25000;
		float cN = 1;
		depth = 1-(-0+(pow(abs(depth),cN))*cF);
		}

		// Skyrim
		if (AltDepthMap == 10)
		{
		float cF = 0.2;
		float cN = 0;
		depth = 1 - (cF) / (cF - depth * ((1 - cN) / (cF - cN * depth)) * (cF - 1));
		}
		
		//Dying Light
		if (AltDepthMap == 11)
		{
		float zF = 1.0;
		float zN = 0.000025;
		float vF = 0.05;		
		depth = (zF * zN / (zN + depth * 1 * (zF - zN)))-(pow(abs(depth*depth),vF));
		}

		//Witcher 3
		if (AltDepthMap == 12)
		{
		float zF = 1.0;
		float zN = 0.00005;
		float vF = 0.110;		
		depth = (zF * zN / (zN + depth * 1 * (zF - zN)))-(pow(abs(depth*depth),vF));
		}
		
		//Fallout 4
		if (AltDepthMap == 13)
		{
		float cF = 25;
		float cN = 1;
		depth = (-0+(pow(abs(depth),cN))*cF);
		}
		
		//Magicka 2
		if (AltDepthMap == 14)
		{
		float cF = 0.001;
		float cM = 0;
		float cN = 0.250;
		depth = (1 * cF / (cF + depth * (depth+cM) * (1 - cF))) / (pow(abs(depth),cN));
		}
		
		//Dragon Dogma
		if (AltDepthMap == 15)
		{
		float cN = -0.02;
		float cF  = 1.025;
		depth = 1 - (1 - cF) / (cN - cF * depth); 
		}

		//Among The Sleep
		if (AltDepthMap == 16)
		{
		float cF = 1.0;
		float cN = 0.010;
		depth = 1 - log(depth/cF)/log(cN/cF);
		}
		
		//Return to Castle Wolfensitne
		if (AltDepthMap == 17)
		{
		float cF = 0.1;
		float cM = 1.0;
		float cN = 0;
		depth = 1 - (1 * cF / (cF + depth * (depth+cM) * (1 - cF))) / (pow(abs(depth),cN));
		}
		
		//Dreamfall Chapters | Firewatch
		if (AltDepthMap == 18)
		{
		float cF = 0.1;
		float cN = 0.0025;		
		depth = 1 - log(depth/cF)/log(cN/cF);
		}		
		
		//CoD: Ghost
		if (AltDepthMap == 19)
		{
		float cF  = 0.00001;
		float cN = 0;
		depth = (cF * 1/depth + cN);
		}
		
		//Metro Redux Games | Borderlands 2
		if (AltDepthMap == 20)
		{
		float LinLog = 0.002;
		depth = 1 - (LinLog) / (LinLog - depth * depth * (LinLog - 1));
		}
		
		//Souls Game
		if (AltDepthMap == 21)
		{
		float cF = 4.55;
		float cN = 2.0;
		depth = 1 - (cN - depth * cN) + (depth*cF);
		}
		
		//Amnesia: The Dark Descent
		if (AltDepthMap == 22)
		{
		float cF  = 1.050;
		float cN = 0;
		depth = 1 - (1 - cF) / (cN - cF * depth); 
		}
		
		//Alien Isolation
		if (AltDepthMap == 23)
		{
		float cF = 20;
		float cN = 0;
		depth = (cN - depth * cN) + (depth*cF);
		}
		
		//Dragon Ball Xeno
		if (AltDepthMap == 24)
		{
		float cF = 0.350;
		float cN = 0;
		depth = 1 - (cF) / (cF - depth * ((1 - cN) / (cF - cN * depth)) * (cF - 1));
		}
		
		//Deadly Premonition: The Directors's Cut
		if (AltDepthMap == 25)
		{
		float cF = 0.15;
		float cN = 0.020;		
		depth = 1 - log(depth/cF)/log(cN/cF);
		}
	}
	else
	{
		//Custom One +
		if (CustomDM == 1)
		{
		float cF = Far;
		float cN = Near;
		depth = (-0+(pow(abs(depth),cN))*cF);
		}
		
		//Custom One -
		if (CustomDM == 2)
		{
		float cF = Far;
		float cN = Near;
		depth = 1-(-0+(pow(abs(depth),cN))*cF);
		}
		
		//Custom Two +
		if (CustomDM == 3)
		{
		float cF  = Far;
		float cN = Near;
		depth = (1 - cF) / (cN - cF * depth); 
		}
		
		//Custom Two -
		if (CustomDM == 4)
		{
		float cF  = Far;
		float cN = Near;
		depth = 1 - (1 - cF) / (cN - cF * depth); 
		}
		
		//Custom Three +
		if (CustomDM == 5)
		{
		float cF  = Far;
		float cN = Near;
		depth = (cF * 1/depth + cN);
		}
		
		//Custom Three -
		if (CustomDM == 6)
		{
		float cF  = Far;
		float cN = Near;
		depth = 1 - (cF * 1/depth + cN);
		}
		
		//Custom Four +
		if (CustomDM == 7)
		{
		float cF = Far;
		float cN = Near;	
		depth = log(depth/cF)/log(cN/cF);
		}
		
		//Custom Four -
		if (CustomDM == 8)
		{
		float cF = Far;
		float cN = Near;
		depth = 1 - log(depth/cF)/log(cN/cF);
		}
		
		//Custom Five +
		if (CustomDM == 9)
		{
		float cF = Far;
		float cN = Near;
		depth = (cF) / (cF - depth * ((1 - cN) / (cF - cN * depth)) * (cF - 1));
		}
		
		//Custom Five -
		if (CustomDM == 10)
		{
		float cF = Far;
		float cN = Near;
		depth = 1 - (cF) / (cF - depth * ((1 - cN) / (cF - cN * depth)) * (cF - 1));
		}
		
		//Custom Six +
		if (CustomDM == 11)
		{
		float cF = Far;
		float cN = Near;
		depth = (cN - depth * cN) + (depth*cF);
		}
		
		//Custom Six -
		if (CustomDM == 12)
		{
		float cF = Far;
		float cN = Near;
		depth = 1 - (cN - depth * cN) + (depth*cF);
		}
	}

    float4 D = depth;	

		color.r = 1 - D.r;
		
	return color.r;	
	}
	
/////////////////////////////////////////L/R/DepthMap Pos//////////////////////////////////////////////////////////
	void  PS_calcLR(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float3 color : SV_Target)
	{
	if(AltRender)
	{
	float DWAL = +WA;
	float DWAR = +WA;
	color.r =  texcoord.x-Depth*pix.x*SbSdepth(float2(texcoord.x-DWAR*pix.x,texcoord.y));
	color.gb =  texcoord.x+Depth*pix.x*SbSdepth(float2(texcoord.x+DWAL*pix.x,texcoord.y));
	}
	else
	{
	float DWAL = 1+WA;
	float DWAR = 1+WA;
	color.r =  texcoord.x+Depth*pix.x*SbSdepth(float2(texcoord.x-DWAR*pix.x,texcoord.y));
	color.gb =  texcoord.x-Depth*pix.x*SbSdepth(float2(texcoord.x+DWAL*pix.x,texcoord.y));
	}
	}

////////////////////////////////////////////////Left Eye////////////////////////////////////////////////////////
void PS_renderL(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float3 color : SV_Target)
{
			//Workaround for DX9 Games
			int x = 5;	
			if (Depth == 0)		
				x = 0;
			else if (Depth == 1)	
				x = 1;
			else if (Depth == 2)
				x = 2;
			else if (Depth == 3)
				x = 3;
			else if (Depth == 4)
				x = 4;
			else if (Depth == 5)
				x = 5;
			else if (Depth == 6)
				x = 6;
			else if (Depth == 7)
				x = 7;
			else if (Depth == 8)
				x = 8;
			else if (Depth == 9)
				x = 9;
			else if (Depth == 10)
				x = 10;
			else if (Depth == 11)
				x = 11;
			else if (Depth == 12)
				x = 12;
			else if (Depth == 13)
				x = 13;
			else if (Depth == 14)
				x = 14;
			else if (Depth == 15)
				x = 15;
			else if (Depth == 16)
				x = 16;
			else if (Depth == 17)
				x = 17;
			else if (Depth == 18)
				x = 18;
			else if (Depth == 19)
				x = 19;			
			else if (Depth == 20)
				x = 20;			
			else if (Depth == 21)
				x = 21;			
			else if (Depth == 22)
				x = 22;			
			else if (Depth == 23)
				x = 23;		
			else if (Depth == 24)
				x = 24;			
			else if (Depth == 25)
				x = 25;
			//Workaround for DX9 Games

		
		float D = Depth/2;
		color.rgb = tex2D(BackBuffer, float2(texcoord.x-D*pix.x, texcoord.y)).rgb;
		
	//Left
	[unroll]
	for (int j = 0; j <= x; ++j) 
	{
		if (AltRender)
		{
		if (tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).b >= texcoord.x+pix.x || tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).b <= tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).b)
		{
			color.rgb = tex2D(BackBuffer, float2(texcoord.x+j*pix.x, texcoord.y)).rgb;
		}
		}
		else
		{
		if (tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).b <= texcoord.x-pix.x || tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).b >= tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).b)
		{
			color.rgb = tex2D(BackBuffer, float2(texcoord.x+j*pix.x, texcoord.y)).rgb;
		}
		}
	}
}


//////////////////////////////////////////Right Eye/////////////////////////////////////////////////////////////
void PS_renderR(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float3 color : SV_Target)
{
			//Workaround for DX9 Games
			int x = 5;	
			if (Depth == 0)		
				x = 0;
			else if (Depth == 1)	
				x = 1;
			else if (Depth == 2)
				x = 2;
			else if (Depth == 3)
				x = 3;
			else if (Depth == 4)
				x = 4;
			else if (Depth == 5)
				x = 5;
			else if (Depth == 6)
				x = 6;
			else if (Depth == 7)
				x = 7;
			else if (Depth == 8)
				x = 8;
			else if (Depth == 9)
				x = 9;
			else if (Depth == 10)
				x = 10;
			else if (Depth == 11)
				x = 11;
			else if (Depth == 12)
				x = 12;
			else if (Depth == 13)
				x = 13;
			else if (Depth == 14)
				x = 14;
			else if (Depth == 15)
				x = 15;
			else if (Depth == 16)
				x = 16;
			else if (Depth == 17)
				x = 17;
			else if (Depth == 18)
				x = 18;
			else if (Depth == 19)
				x = 19;			
			else if (Depth == 20)
				x = 20;			
			else if (Depth == 21)
				x = 21;			
			else if (Depth == 22)
				x = 22;			
			else if (Depth == 23)
				x = 23;		
			else if (Depth == 24)
				x = 24;			
			else if (Depth == 25)
				x = 25;
			//Workaround for DX9 Games
		
		float D = Depth/2;
		color.rgb = tex2D(BackBuffer, float2(texcoord.x-D*pix.x, texcoord.y)).rgb;
		/////////////////GOOOD///////////////////
	//Right
	[unroll]
	for (int j = 0; j >= -x; --j) 
	{
		if (AltRender)
		{
			if (tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).r <= texcoord.x+pix.x || tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).r <= tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).r)
			{
				color.rgb = tex2D(BackBuffer, float2(texcoord.x+j*pix.x, texcoord.y)).rgb;
			}
		}
		else
		{
			if (tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).r >= texcoord.x-pix.x || tex2D(SamplerCC,float2(texcoord.x+j*pix.x,texcoord.y)).r >= tex2D(SamplerCC,float2(texcoord.x-j*pix.x,texcoord.y)).r)
			{
				color.rgb = tex2D(BackBuffer, float2(texcoord.x+j*pix.x, texcoord.y)).rgb;
			}
		}
	}

}

//////////////////////////////////////////////////////Barrle_Distortion/////////////////////////////////////////////////////
float3 BDL(float2 texcoord)

{
	float k = K;
	float kcube = KCube;

	float r2 = (texcoord.x-0.5) * (texcoord.x-0.5) + (texcoord.y-0.5) * (texcoord.y-0.5);       
	float f = 0.0;

	f = 1 + r2 * (k + kcube * sqrt(r2));

	float x = f*(texcoord.x-0.5)+0.5;
	float y = f*(texcoord.y-0.5)+0.5;
	float3 BDListortion = tex2D(SamplerCL,float2(x,y)).rgb;

	return BDListortion.rgb;
}

float3 BDR(float2 texcoord)

{
	float k = K;
	float kcube = KCube;

	float r2 = (texcoord.x-0.5) * (texcoord.x-0.5) + (texcoord.y-0.5) * (texcoord.y-0.5);       
	float f = 0.0;

	f = 1 + r2 * (k + kcube * sqrt(r2));

	float x = f*(texcoord.x-0.5)+0.5;
	float y = f*(texcoord.y-0.5)+0.5;
	float3 BDRistortion = tex2D(SamplerCR,float2(x,y)).rgb;

	return BDRistortion.rgb;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void PS0(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float3 color : SV_Target)
{
	float pos = Hsquish-1;
	float mid = pos*BUFFER_HEIGHT/2*pix.y;

	if(BD)
	{
		color = texcoord.x > 0.5 ? BDL(float2(texcoord.x*2-1 + Perspective * pix.x,(texcoord.y*Hsquish)-mid)).rgb : BDR(float2(texcoord.x*2 - Perspective * pix.x,(texcoord.y*Hsquish)-mid)).rgb;
	}
	else
	{
		color = texcoord.x > 0.5 ? tex2D(SamplerCL, float2(texcoord.x*2-1 + Perspective * pix.x, texcoord.y)).rgb : tex2D(SamplerCR, float2(texcoord.x*2 - Perspective * pix.x, texcoord.y)).rgb;
	}
}

///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

///////////////////////////////////////////////Depth Map View//////////////////////////////////////////////////////////////////////
float4 PS(float4 pos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
		
	float4 color = tex2D(SamplerCC, texcoord);
		
		
		if (DepthFlip)
		texcoord.y = 1 - texcoord.y;
		
		float4 depthM = tex2D(DepthBuffer, float2(texcoord.x, texcoord.y));
		
		if (CustomDM == 0)
	{	
		//Alien Isolation
		if (AltDepthMap == 0)
		{
		float cF = 0.9125;
		float cN = 0.9125;
		depthM = 1 - (cF) / (cF - depthM * ((1 - cN) / (cF - cN * depthM)) * (cF - 1));
		}
		
		//Batman Games
		if (AltDepthMap == 1)
		{
		float cF = 5;
		float cN = 0;
		depthM = (cN - depthM * cN) + (depthM * cF);
		}
		
		////Quake 2 XP
		if (AltDepthMap == 2)
		{
		float cF  = 0.01;
		float cN = 0;
		depthM = 1 - (cF * 1/depthM + cN);
		}
		
		//The Evil Within
		if (AltDepthMap == 3)
		{
		float cF = 1.5;
		float cN = 0;
		depthM = (cN - depthM * cN) + (depthM*cF);
		}
		
		//Sleeping Dogs:  DE
		if (AltDepthMap == 4)
		{
		float zF = 1.0;
		float zN = 0.025;
		depthM = 1 - (zF * zN / (zN + depthM * (zF - zN)) + pow(abs(depthM*depthM),1.0));
		}

		//Call of Duty: Advance Warfare
		if (AltDepthMap == 5)
		{
		float cF  = 0.00001;
		float cN = 0;
		depthM = (cF * 1/depthM + cN);
		}
		
		//Lords of the Fallen
		if (AltDepthMap == 6)
		{
		float cF  = 1.027;
		float cN = 0;
		depthM = 1 - (1 - cF) / (cN - cF * depthM); 
		}
		
		//Shadow Warrior
		if (AltDepthMap == 7)
		{
		float cF = 10;
		float cN = 0;
		depthM = (cN - depthM * cN) + (depthM*cF);
		}
		
		//Rage
		if (AltDepthMap == 8)
		{
		float LinLog = 0.005;
		depthM = (1 - (LinLog) / (LinLog - depthM * 1.5 * (LinLog -  0.05)))+(pow(abs(depthM*depthM),3.5));
		}
		
		//Assassin Creed Unity
		if (AltDepthMap == 9)
		{
		float cF = 25000;
		float cN = 1;
		depthM = 1-(-0+(pow(abs(depthM),cN))*cF);
		}
		
		//Skyrim
		if (AltDepthMap == 10)
		{
		float cF = 0.2;
		float cN = 0;
		depthM = 1 - (cF) / (cF - depthM * ((1 - cN) / (cF - cN * depthM)) * (cF - 1));
		}
		
		//Dying Light
		if (AltDepthMap == 11)
		{
		float zF = 1.0;
		float zN = 0.000025;
		float vF = 0.05;	
		depthM = (zF * zN / (zN + depthM * 1 * (zF - zN)))-(pow(abs(depthM*depthM),vF));
		}

		//Witcher 3
		if (AltDepthMap == 12)
		{
		float zF = 1.0;
		float zN = 0.00005;
		float vF = 0.110;	
		depthM = (zF * zN / (zN + depthM * 1 * (zF - zN)))-(pow(abs(depthM*depthM),vF));
		}
		
		//Fallout 4
		if (AltDepthMap == 13)
		{
		float cF = 25;
		float cN = 1;
		depthM = (-0+(pow(abs(depthM),cN))*cF);
		}
		
		//Magicka 2
		if (AltDepthMap == 14)
		{
		float cF = 0.001;
		float cM = 0;
		float cN = 0.250;
		depthM = (1 * cF / (cF + depthM * (depthM+cM) * (1 - cF))) / (pow(abs(depthM),cN));
		}
		
		//Dragon Dogma
		if (AltDepthMap == 15)
		{
		float cN = -0.02;
		float cF  = 1.025;
		depthM = 1 - (1 - cF) / (cN - cF * depthM); 
		}
		
		//Among The Sleep
		if (AltDepthMap == 16)
		{
		float cF = 1.0;
		float cN = 0.010;	
		depthM = 1 - log(depthM/cF)/log(cN/cF);
		}
		
		//Return to Castle Wolfensitne
		if (AltDepthMap == 17)
		{
		float cF = 0.1;
		float cM = 1.0;
		float cN = 0;
		depthM = 1 - (1 * cF / (cF + depthM * (depthM+cM) * (1 - cF))) / (pow(abs(depthM),cN));
		}	
		
		//Dreamfall Chapters | Firewatch
		if (AltDepthMap == 18)
		{
		float cF = 0.1;
		float cN = 0.0025;		
		depthM = 1 - log(depthM/cF)/log(cN/cF);
		}
				
		//CoD: Ghost
		if (AltDepthMap == 19)
		{
		float cF  = 0.00001;
		float cN = 0;
		depthM = (cF * 1/depthM + cN);
		}
		
		//Metro Redux Games | Borderlands 2
		if (AltDepthMap == 20)
		{
		float LinLog = 0.002;
		depthM = 1 - (LinLog) / (LinLog - depthM * depthM * (LinLog - 1));
		}
		
		//Souls Game
		if (AltDepthMap == 21)
		{
		float cF = 4.55;
		float cN = 2.0;
		depthM = 1 - (cN - depthM * cN) + (depthM*cF);
		}
	
		//Amnesia: The Dark Descent
		if (AltDepthMap == 22)
		{
		float cF  = 1.050;
		float cN = 0;
		depthM = 1 - (1 - cF) / (cN - cF * depthM); 
		}
		
		//Alien Isolation
		if (AltDepthMap == 23)
		{
		float cF = 20;
		float cN = 0;
		depthM = (cN - depthM * cN) + (depthM * cF);
		}
		
		//Dragon Ball Xeno
		if (AltDepthMap == 24)
		{
		float cF = 0.350;
		float cN = 0;
		depthM = 1 - (cF) / (cF - depthM * ((1 - cN) / (cF - cN * depthM)) * (cF - 1));
		}
		
		//Deadly Premonition: The Directors's Cut
		if (AltDepthMap == 25)
		{
		float cF = 0.15;
		float cN = 0.020;		
		depthM = 1 - log(depthM/cF)/log(cN/cF);
		}
	}
	else
	{
		//Custom One +
		if (CustomDM == 1)
		{
		float cF = Far;
		float cN = Near;
		depthM = (-0+(pow(abs(depthM),cN))*cF);
		}
		
		//Custom One -
		if (CustomDM == 2)
		{
		float cF = Far;
		float cN = Near;
		depthM = 1-(-0+(pow(abs(depthM),cN))*cF);
		}
		
		//Custom Two +
		if (CustomDM == 3)
		{
		float cF  = Far;
		float cN = Near;
		depthM = (1 - cF) / (cN - cF * depthM); 
		}
		
		//Custom Two -
		if (CustomDM == 4)
		{
		float cF  = Far;
		float cN = Near;
		depthM = 1 - (1 - cF) / (cN - cF * depthM); 
		}
		
		//Custom Three +
		if (CustomDM == 5)
		{
		float cF  = Far;
		float cN = Near;
		depthM = (cF * 1/depthM + cN);
		}
		
		//Custom Three -
		if (CustomDM == 6)
		{
		float cF  = Far;
		float cN = Near;
		depthM = 1 - (cF * 1/depthM + cN);
		}
		
		//Custom Four +
		if (CustomDM == 7)
		{
		float cF = Far;
		float cN = Near;	
		depthM = log(depthM/cF)/log(cN/cF);
		}
		
		//Custom Four -
		if (CustomDM == 8)
		{
		float cF = Far;
		float cN = Near;	
		depthM = 1 - log(depthM/cF)/log(cN/cF);
		}
		
		//Custom Five +
		if (CustomDM == 9)
		{
		float cF = Far;
		float cN = Near;
		depthM = (cF) / (cF - depthM * ((1 - cN) / (cF - cN * depthM)) * (cF - 1));
		}
		
		//Custom Five -
		if (CustomDM == 10)
		{
		float cF = Far;
		float cN = Near;
		depthM = 1 - (cF) / (cF - depthM * ((1 - cN) / (cF - cN * depthM)) * (cF - 1));
		}
		
		//Custom Six +
		if (CustomDM == 11)
		{
		float cF = Far;
		float cN = Near;
		depthM = (cN - depthM * cN) + (depthM * cF);
		}
		
		//Custom Six -
		if (CustomDM == 12)
		{
		float cF = Far;
		float cN = Near;
		depthM = 1 - (cN - depthM * cN) + (depthM * cF);
		}
	}
	
	float4 DM = depthM;
	
	if (DepthMap)
	{
	color.rgb = DM.rrr;				
	}
	return color;
	}

//*Rendering passes*//

technique Super_Depth3D
	{
			pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS_calcLR;
			RenderTarget = texCC;
		}
			pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS_renderL;
			RenderTarget = texCL;
		}
			pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS_renderR;
			RenderTarget = texCR;
		}
			pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS0;
			RenderTarget = texCC;
		}
			pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS;
		}
	}