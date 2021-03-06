 ////----------------------//
 ///**2D to 3D converter**///
 //----------------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* 2D+ Psudo Depth Based on Unsharp Mask                        																													*//
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
 //*                                                                            																									*//
 //* 																																												*//
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Determines The Max Depth amount. The larger the amount harder it will hit on FPS will be.

#define Depth_Max 25

uniform int Divergence <
	ui_type = "drag";
	ui_min = 1; ui_max = Depth_Max;
	ui_label = "Divergence Slider";
	ui_tooltip = "Determines the amount of Image Warping and Separation.\n" 
				 "You can override this value.";
> = 15;

uniform float Perspective <
	ui_type = "drag";
	ui_min = -50.0; ui_max = 50.0;
	ui_label = "Perspective Slider";
	ui_tooltip = "Determines the perspective point. Default is 0";
> = 0.0;

uniform int Stereoscopic_Mode <
	ui_type = "combo";
	ui_items = "Side by Side\0Top and Bottom\0Line Interlaced\0Column Interlaced\0Checkerboard 3D\0Anaglyph\0";
	ui_label = "3D Display Mode";
	ui_tooltip = "Stereoscopic 3D display output selection.";
> = 0;

uniform int Scaling_Support <
	ui_type = "combo";
	ui_items = " 2160p\0 Native\0 1080p A\0 1080p B\0 1050p A\0 1050p B\0 720p A\0 720p B\0";
	ui_label = "Scaling Support";
	ui_tooltip = "Dynamic Super Resolution , Virtual Super Resolution, downscaling, or Upscaling support for Line Interlaced, Column Interlaced, & Checkerboard 3D displays.";
> = 1;

uniform int Anaglyph_Colors <
	ui_type = "combo";
	ui_items = "Red/Cyan\0Dubois Red/Cyan\0Green/Magenta\0Dubois Green/Magenta\0";
	ui_label = "Anaglyph Color Mode";
	ui_tooltip = "Select colors for your 3D anaglyph glasses.";
> = 0;

uniform float Anaglyph_Desaturation <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Anaglyph Desaturation";
	ui_tooltip = "Adjust anaglyph desaturation, Zero is Black & White, One is full color.";
> = 1.0;

uniform bool Eye_Swap <
	ui_label = "Swap Eyes";
	ui_tooltip = "L/R to R/L.";
> = false;

uniform bool Debug_View <
	ui_label = "Debug View";
	ui_tooltip = "Debug View.";
> = false;

uniform float Power <
	ui_type = "drag";
	ui_min = 0.5; ui_max = 1.0;
	ui_label = "Shade Power";
	ui_tooltip = "Adjust the Shade Power Lower is Higher & Higher is Lower.\n"
				 "This improves AO, Shadows, & Darker Areas in game.\n"
				 "Number 1.0 is default.";
> = 1.0;

uniform float Spread <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 20.0;
	ui_label = "Shade Fill";
	ui_tooltip = "Adjust This to have the shade effect to fill in areas.\n"
				 "This is used for gap filling. AKA, Fake AO.\n"
				 "Number 7.5 is default.";
> = 7.5;

uniform int Mode <
	ui_type = "combo";
	ui_items = "Mode A\0Mode B\0Mode C\0";
	ui_label = "Anaglyph Color Mode";
	ui_tooltip = "Select colors for your 3D anaglyph glasses.";
> = 0;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define TextureSize float2(BUFFER_WIDTH, BUFFER_HEIGHT)
	
texture BackBufferTex : COLOR;

sampler BackBuffer 
	{ 
		Texture = BackBufferTex;
	};
	
	

texture texBlur { Width = BUFFER_WIDTH*0.5; Height = BUFFER_HEIGHT*0.5; Format = RGBA8; MipLevels = 8;};

sampler SamplerBlur
	{
		Texture = texBlur;
		MipLODBias = 2.0f;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
	};	

texture texFakeDB { Width = BUFFER_WIDTH*0.5; Height = BUFFER_HEIGHT*0.5; Format = RGBA8; MipLevels = 8;};

sampler SamplerFakeDB
	{
		Texture = texFakeDB;
		MipLODBias = 2.0f;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
	};
	
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float3 rgb2hsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    //return dot(float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x), float3(0.3, 0.59, 0.11));//Gray-scale conversion.
}

float4 rgb2yuv(float3 rgb)
{
	float4 yuv;
	yuv.x = rgb.r * 0.299 + rgb.g * 0.587 + rgb.b * 0.114;
	yuv.y = rgb.r * -0.169 + rgb.g * -0.331 + rgb.b * 0.5 + 0.5;
	yuv.z = rgb.r * 0.5 + rgb.g * -0.419 + rgb.b * -0.081 + 0.5;
	
	return yuv;
}

void Blur(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float4 color : SV_Target0)                                                                          
{
   float4 tl = tex2D(BackBuffer,texcoord);
   float4 tr = tex2D(BackBuffer,texcoord +float2(pix.x, 0.0));
   float4 bl = tex2D(BackBuffer,texcoord +float2(0.0, pix.y));
   float4 br = tex2D(BackBuffer,texcoord +float2(pix.x, pix.y));
   float2 f = frac( texcoord * TextureSize );
   float4 tA = lerp( tl, tr, f.x );
   float4 tB = lerp( bl, br, f.x );
   float4 done = lerp( tA, tB, f.y );//2.0 Gamma correction.
 color = done;
}

float4 Adjust(in float2 texcoord : TEXCOORD0)
{
float2 S = float2(Spread * pix.x,Spread * pix.y);// Hoizontal Sepration needs to be stronger
float4 H = lerp(tex2D(SamplerBlur, float2(texcoord.x + S.x, texcoord.y)),tex2D(SamplerBlur, float2(texcoord.x - S.x, texcoord.y)),0.5);
float4 V = lerp(tex2D(SamplerBlur, float2(texcoord.x, texcoord.y + S.y)),tex2D(SamplerBlur, float2(texcoord.x, texcoord.y - S.y)),0.5);
float4 HVC = lerp(H,V,0.50);

return HVC; 
}

float3 GS(float3 color)
{
    float grayscale = dot(color.rgb, float3(0.3, 0.59, 0.11));
    color.r = grayscale;
    color.g = grayscale;
    color.b = grayscale;
	return clamp(color,0.003,1.0);//clamping to protect from over Dark.
}

float4 FakeDB(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0): SV_Target
{
	//Luma (SD video)	float3(0.299, 0.587, 0.114)
	//Luma (HD video)	float3(0.2126, 0.7152, 0.0722) https://en.wikipedia.org/wiki/Luma_(video)
	//Luma (HDR video)	float3(0.2627, 0.6780, 0.0593) https://en.wikipedia.org/wiki/Rec._2100
	float3 RGB_A, RGB_B, Luma_Coefficient = float3(0.2627, 0.6780, 0.0593);
		
	//Formula for Image Pop = Original + (Original / Blurred) * Amount.
	RGB_A = GS( tex2D(BackBuffer,texcoord).rgb ) / GS( Adjust(texcoord).rgb );
	float3 FGPop = GS(RGB_A.rgb);
	
	//Formula for BackGround Pop = Original + (Original - Blurred) * Amount .
	RGB_B = GS(tex2D(BackBuffer,texcoord).rgb) - GS(Adjust(texcoord).rgb);
	float3 BGPop = GS(1-RGB_B.rgb);
	
	//RGB = saturate(RGB_A);
	float BG = dot(BGPop,Luma_Coefficient);
	float FG = dot(FGPop,Luma_Coefficient);
	
	float3 BGt = 1-(saturate(BG)*(1-(rgb2yuv(tex2D(BackBuffer,texcoord).rgb).ggg*rgb2yuv(tex2D(BackBuffer,texcoord).rgb).bbb)));
	float3 FGt = 1-(saturate(FG)*(1-(rgb2yuv(tex2D(BackBuffer,texcoord).rgb).ggg*rgb2yuv(tex2D(BackBuffer,texcoord).rgb).bbb)));
	
	float3 Done = 1-tex2D(BackBuffer,texcoord).rgb;
	
	float Num;
	if(Mode == 0)
	{
	Done = GS(Done);
	Num = 0.250;
	}
	else if(Mode == 1)
	{
	Done = rgb2yuv(Done).rgb;
	Num = 0.250;
	}
	else
	{
	Done = rgb2hsv(Done);
	Num = 0.500;
	}
	
	float RGB = smoothstep(0,Power,1-distance(smoothstep(0,Num,FGt*BGt),Done));
	
	return float4(RGB,RGB,RGB,1);
}

float4  Encode(in float2 texcoord : TEXCOORD0) //zBuffer Color Channel Encode
{

	float GetDepthR = tex2D(SamplerFakeDB,float2(texcoord.x,texcoord.y)).x;
	float GetDepthB = tex2D(SamplerFakeDB,float2(texcoord.x,texcoord.y)).x;

	// X	
	float Rx = (1-texcoord.x)+Divergence*pix.x*GetDepthR;
	// Y
	float Ry = (1-texcoord.x)+Divergence*pix.x*GetDepthR;
	// Z
	float Bz = texcoord.x+Divergence*pix.x*GetDepthB;
	// W
	float Bw = texcoord.x+Divergence*pix.x*GetDepthB;
	
	float R = Rx; //X Encode
	float G = Ry; //Y Encode
	float B = Bz; //Z Encode
	float A = Bw; //W Encode
	
	return float4(R,G,B,A);
}

float4 Converter(float2 texcoord : TEXCOORD0)
{		
	float4 Out;
	float2 TCL,TCR;
	//float Perspective = (Divergence * 0.5) + P;
	if (Stereoscopic_Mode == 0)
		{
		if (Eye_Swap)
			{
				TCL.x = (texcoord.x*2) - Perspective * pix.x;
				TCR.x = (texcoord.x*2-1) + Perspective * pix.x;
				TCL.y = texcoord.y;
				TCR.y = texcoord.y;
			}
		else
			{
				TCL.x = (texcoord.x*2-1) - Perspective * pix.x;
				TCR.x = (texcoord.x*2) + Perspective * pix.x;
				TCL.y = texcoord.y;
				TCR.y = texcoord.y;
			}
		}
	else if(Stereoscopic_Mode == 1)
		{
		if (Eye_Swap)
			{
			TCL.x = texcoord.x - Perspective * pix.x;
			TCR.x = texcoord.x + Perspective * pix.x;
			TCL.y = texcoord.y*2;
			TCR.y = texcoord.y*2-1;
			}
		else
			{
			TCL.x = texcoord.x - Perspective * pix.x;
			TCR.x = texcoord.x + Perspective * pix.x;
			TCL.y = texcoord.y*2-1;
			TCR.y = texcoord.y*2;
			}
		}
	else
		{
			TCL.x = texcoord.x - Perspective * pix.x;
			TCR.x = texcoord.x + Perspective * pix.x;
			TCL.y = texcoord.y;
			TCR.y = texcoord.y;
		}
		
	
		float4 cL, LL; //tex2D(BackBuffer,float2(TCL.x,TCL.y)); //objects that hit screen boundary is replaced with the BackBuffer 		
		float4 cR, RR; //tex2D(BackBuffer,float2(TCR.x,TCR.y)); //objects that hit screen boundary is replaced with the BackBuffer
		float RF, RN, LF, LN;
		int x = Depth_Max;		
		[loop]
		for (int i = 0; i <= x+1; i++) 
		{
				//R Good
				//if ( Encode(float2(TCR.x+i*pix.x,TCR.y)).x >= (1-TCR.x-pix.x/2) && Encode(float2(TCR.x+i*pix.x,TCR.y)).x <= (1-TCR.x+pix.x/2) ) //Decode X
				if ( Encode(float2(TCR.x+i*pix.x,TCR.y)).x >= (1-TCR.x) )
				{
				RF = i * pix.x; //Good
				}

				//L Good
				//if ( Encode(float2(TCL.x-i*pix.x,TCL.y)).z >= TCL.x-pix.x/2 && Encode(float2(TCL.x-i*pix.x,TCL.y)).z <= (TCR.x+pix.x/2)) //Decode Z
				if ( Encode(float2(TCL.x-i*pix.x,TCL.y)).z >= TCL.x )
				{
				LF = i * pix.x; //Good
				}
		}
			
		cR = tex2Dlod(BackBuffer, float4(TCR.x+RF,TCR.y,0,0)); //Good
		cL = tex2Dlod(BackBuffer, float4(TCL.x-LF,TCL.y,0,0)); //Good

	
			if ( Eye_Swap )
			{
				cR = tex2Dlod(BackBuffer, float4(TCR.x+RF,TCR.y,0,0)); //Good
				cL = tex2Dlod(BackBuffer, float4(TCL.x-LF,TCL.y,0,0)); //Good
			}
			else
			{
				cL = tex2Dlod(BackBuffer, float4(TCR.x+RF,TCR.y,0,0)); //Good
				cR = tex2Dlod(BackBuffer, float4(TCL.x-LF,TCL.y,0,0)); //Good
			}
			

	float2 gridxy;

	if(Scaling_Support == 0)
	{
		gridxy = floor(float2(texcoord.x*3840.0,texcoord.y*2160.0));
	}	
	else if(Scaling_Support == 1)
	{
		gridxy = floor(float2(texcoord.x*BUFFER_WIDTH,texcoord.y*BUFFER_HEIGHT));
	}
	else if(Scaling_Support == 2)
	{
		gridxy = floor(float2(texcoord.x*1920.0,texcoord.y*1080.0));
	}
	else if(Scaling_Support == 3)
	{
		gridxy = floor(float2(texcoord.x*1921.0,texcoord.y*1081.0));
	}
	else if(Scaling_Support == 4)
	{
		gridxy = floor(float2(texcoord.x*1680.0,texcoord.y*1050.0));
	}
	else if(Scaling_Support == 5)
	{
		gridxy = floor(float2(texcoord.x*1681.0,texcoord.y*1051.0));
	}
	else if(Scaling_Support == 6)
	{
		gridxy = floor(float2(texcoord.x*1280.0,texcoord.y*720.0));
	}
	else if(Scaling_Support == 7)
	{
		gridxy = floor(float2(texcoord.x*1281.0,texcoord.y*721.0));
	}
			
		if(Stereoscopic_Mode == 0)
		{	
			Out = texcoord.x < 0.5 ? cL : cR;
		}
		else if(Stereoscopic_Mode == 1)
		{	
			Out = texcoord.y < 0.5 ? cL : cR;
		}
		else if(Stereoscopic_Mode == 2)
		{
			Out = int(gridxy.y) & 1 ? cR : cL;	
		}
		else if(Stereoscopic_Mode == 3)
		{
			Out = int(gridxy.x) & 1 ? cR : cL;		
		}
		else if(Stereoscopic_Mode == 4)
		{
			Out = int(gridxy.x+gridxy.y) & 1 ? cR : cL;
		}
		else if(Stereoscopic_Mode == 5)
		{													
				float3 HalfLA = dot(cL.rgb,float3(0.299, 0.587, 0.114));
				float3 HalfRA = dot(cR.rgb,float3(0.299, 0.587, 0.114));
				float3 LMA = lerp(HalfLA,cL.rgb,Anaglyph_Desaturation);  
				float3 RMA = lerp(HalfRA,cR.rgb,Anaglyph_Desaturation); 
				
				float4 cA = float4(LMA,1);
				float4 cB = float4(RMA,1);
	
			if (Anaglyph_Colors == 0)
			{
				float4 LeftEyecolor = float4(1.0,0.0,0.0,1.0);
				float4 RightEyecolor = float4(0.0,1.0,1.0,1.0);
				
				Out =  (cA*LeftEyecolor) + (cB*RightEyecolor);
			}
			else if (Anaglyph_Colors == 1)
			{
			float red = 0.437 * cA.r + 0.449 * cA.g + 0.164 * cA.b
					- 0.011 * cB.r - 0.032 * cB.g - 0.007 * cB.b;
			
			if (red > 1) { red = 1; }   if (red < 0) { red = 0; }

			float green = -0.062 * cA.r -0.062 * cA.g -0.024 * cA.b 
						+ 0.377 * cB.r + 0.761 * cB.g + 0.009 * cB.b;
			
			if (green > 1) { green = 1; }   if (green < 0) { green = 0; }

			float blue = -0.048 * cA.r - 0.050 * cA.g - 0.017 * cA.b 
						-0.026 * cB.r -0.093 * cB.g + 1.234  * cB.b;
			
			if (blue > 1) { blue = 1; }   if (blue < 0) { blue = 0; }

			Out = float4(red, green, blue, 0);
			}
			else if (Anaglyph_Colors == 2)
			{
				float4 LeftEyecolor = float4(0.0,1.0,0.0,1.0);
				float4 RightEyecolor = float4(1.0,0.0,1.0,1.0);
				
				Out =  (cA*LeftEyecolor) + (cB*RightEyecolor);			
			}
			else
			{
								
			float red = -0.062 * cA.r -0.158 * cA.g -0.039 * cA.b
					+ 0.529 * cB.r + 0.705 * cB.g + 0.024 * cB.b;
			
			if (red > 1) { red = 1; }   if (red < 0) { red = 0; }

			float green = 0.284 * cA.r + 0.668 * cA.g + 0.143 * cA.b 
						- 0.016 * cB.r - 0.015 * cB.g + 0.065 * cB.b;
			
			if (green > 1) { green = 1; }   if (green < 0) { green = 0; }

			float blue = -0.015 * cA.r -0.027 * cA.g + 0.021 * cA.b 
						+ 0.009 * cB.r + 0.075 * cB.g + 0.937  * cB.b;
			
			if (blue > 1) { blue = 1; }   if (blue < 0) { blue = 0; }
					
			Out = float4(red, green, blue, 0);
			}
		}
	
			if(Debug_View)
			Out.rgb = tex2D(SamplerFakeDB,texcoord).xxx;

	return float4(Out.rgb,1);
	}

////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
uniform float timer < source = "timer"; >;
float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.5*BUFFER_WIDTH*pix.x,PosY = 0.5*BUFFER_HEIGHT*pix.y;	
	float4 Color = Converter(texcoord),Done,Website,D,E,P,T,H,Three,DD,Dot,I,N,F,O;
	
	if(timer <= 10000)
	{
	//DEPTH
	//D
	float PosXD = -0.035+PosX, offsetD = 0.001;
	float4 OneD = all( abs(float2( texcoord.x -PosXD, texcoord.y-PosY)) < float2(0.0025,0.009));
	float4 TwoD = all( abs(float2( texcoord.x -PosXD-offsetD, texcoord.y-PosY)) < float2(0.0025,0.007));
	D = OneD-TwoD;
	
	//E
	float PosXE = -0.028+PosX, offsetE = 0.0005;
	float4 OneE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.009));
	float4 TwoE = all( abs(float2( texcoord.x -PosXE-offsetE, texcoord.y-PosY)) < float2(0.0025,0.007));
	float4 ThreeE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.001));
	E = (OneE-TwoE)+ThreeE;
	
	//P
	float PosXP = -0.0215+PosX, PosYP = -0.0025+PosY, offsetP = 0.001, offsetP1 = 0.002;
	float4 OneP = all( abs(float2( texcoord.x -PosXP, texcoord.y-PosYP)) < float2(0.0025,0.009*0.682));
	float4 TwoP = all( abs(float2( texcoord.x -PosXP-offsetP, texcoord.y-PosYP)) < float2(0.0025,0.007*0.682));
	float4 ThreeP = all( abs(float2( texcoord.x -PosXP+offsetP1, texcoord.y-PosY)) < float2(0.0005,0.009));
	P = (OneP-TwoP) + ThreeP;

	//T
	float PosXT = -0.014+PosX, PosYT = -0.008+PosY;
	float4 OneT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosYT)) < float2(0.003,0.001));
	float4 TwoT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosY)) < float2(0.000625,0.009));
	T = OneT+TwoT;
	
	//H
	float PosXH = -0.0071+PosX;
	float4 OneH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.001));
	float4 TwoH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.009));
	float4 ThreeH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.003,0.009));
	H = (OneH-TwoH)+ThreeH;
	
	//Three
	float offsetFive = 0.001, PosX3 = -0.001+PosX;
	float4 OneThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.009));
	float4 TwoThree = all( abs(float2( texcoord.x -PosX3 - offsetFive, texcoord.y-PosY)) < float2(0.003,0.007));
	float4 ThreeThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.001));
	Three = (OneThree-TwoThree)+ThreeThree;
	
	//DD
	float PosXDD = 0.006+PosX, offsetDD = 0.001;	
	float4 OneDD = all( abs(float2( texcoord.x -PosXDD, texcoord.y-PosY)) < float2(0.0025,0.009));
	float4 TwoDD = all( abs(float2( texcoord.x -PosXDD-offsetDD, texcoord.y-PosY)) < float2(0.0025,0.007));
	DD = OneDD-TwoDD;
	
	//Dot
	float PosXDot = 0.011+PosX, PosYDot = 0.008+PosY;		
	float4 OneDot = all( abs(float2( texcoord.x -PosXDot, texcoord.y-PosYDot)) < float2(0.00075,0.0015));
	Dot = OneDot;
	
	//INFO
	//I
	float PosXI = 0.0155+PosX, PosYI = 0.004+PosY, PosYII = 0.008+PosY;
	float4 OneI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosY)) < float2(0.003,0.001));
	float4 TwoI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYI)) < float2(0.000625,0.005));
	float4 ThreeI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYII)) < float2(0.003,0.001));
	I = OneI+TwoI+ThreeI;
	
	//N
	float PosXN = 0.0225+PosX, PosYN = 0.005+PosY,offsetN = -0.001;
	float4 OneN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN)) < float2(0.002,0.004));
	float4 TwoN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN - offsetN)) < float2(0.003,0.005));
	N = OneN-TwoN;
	
	//F
	float PosXF = 0.029+PosX, PosYF = 0.004+PosY, offsetF = 0.0005, offsetF1 = 0.001;
	float4 OneF = all( abs(float2( texcoord.x -PosXF-offsetF, texcoord.y-PosYF-offsetF1)) < float2(0.002,0.004));
	float4 TwoF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0025,0.005));
	float4 ThreeF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0015,0.00075));
	F = (OneF-TwoF)+ThreeF;
	
	//O
	float PosXO = 0.035+PosX, PosYO = 0.004+PosY;
	float4 OneO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.003,0.005));
	float4 TwoO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.002,0.003));
	O = OneO-TwoO;
	}
	
	Website = D+E+P+T+H+Three+DD+Dot+I+N+F+O ? float4(1.0,1.0,1.0,1) : Color;
	
	if(timer >= 10000)
	{
	Done = Color;
	}
	else
	{
	Done = Website;
	}

	return Done;
}

///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Dimension_Plus
{
			pass BlurFilter
		{
			VertexShader = PostProcessVS;
			PixelShader = Blur;
			RenderTarget = texBlur;
		}	
			pass FakeDBFilter
		{
			VertexShader = PostProcessVS;
			PixelShader = FakeDB;
			RenderTarget = texFakeDB;
		}	
			pass CuesUnsharpMask
		{
			VertexShader = PostProcessVS;
			PixelShader = Out;	
		}
}
