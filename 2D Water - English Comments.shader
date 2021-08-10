Shader "Custom/2D Water"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NoiseTex("Noise Texture (Optional for randomness)", 2D) = "white" {}
		 _FlowSpeedDir("Flow Speed (X,Y)", Vector) = (1,1,0,0)
		_WaveA("Wave Properties (ength, Speed, Steepness)",Vector) = (1,1,1)
		_WaveB("Wave Properties",Vector) = (1,1,1)	
		_WaveC("Wave Properties",Vector) = (1,1,1)
		_WaveSplash("Wave Splash (Frequency, Speed, Amplitude, Distance)",Vector) = (1,1,1)
		_hitEffectSpread("Hit Spread (0.001 means maximum spread)", Range(0.001,1)) = 0.25 
		[Header(Fade Effect)]
		[Toggle] _Fade("Fade Water Object?", Float) = 0
		_FadeOrigin ("Fade Origin (Where to start the fade)",Range(0,1)) = 1
		_FadeEnd ("Fade End (Where to end the fade)",Range(0,1)) = 0
		_StartAlpha ("Alpha at Fade Origin",Range(0,1.0)) = 1.0
		_EndAlpha   ("Alpha at Fade End",Range(0,1.0)) = 1.0
    }
    SubShader
    {
		Cull Off
		Tags{ "Queue"="Transparent" "RenderType"="Transparent"}

		ZWrite Off
		Blend SrcALpha  OneMinusSrcAlpha
        // Regular color & lighting pass
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 4.0
			// Properties
			sampler2D _MainTex;
          	sampler2D _NoiseTex;
			float4 _Color;
			float2 _FlowSpeedDir;
			float4 _MainTex_ST;
			float3 _WaveA;
			float3 _WaveB;
			float3 _WaveC;
			float3 _WaveSplash;
			float3 _WaveSplashB;
		
			float _hitEffectSpread;
			
			float _Fade;
			float _FadeOrigin;
			float _FadeEnd;
			float _StartAlpha;
			float _EndAlpha;

			//10 is the maximum splashes happening at the same time
			float2 SplashesArray[10]; //X is hit position. Y is hitEffect.

			static float PI = 3.14159265359;


			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 texCoord : TEXCOORD0;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float3 texCoord : TEXCOORD0;
			};

			float3 Wave2D(float3 waveProp, float3 _point, float randomNum){
				//frequency of a sine wave is 2pi/period, period is the waveLength
				float frequency = 2 * PI / waveProp.x; //x is waveLength
				float offset = _point.x;
				//sin(B(x-c)), a is the frequency,
				//c is the horizontal displacement, and to change it over time, we multiply it with the current time,
				//then we multiply it by the speed to change, obviously, the speed.
				float factor =   frequency * ( offset  - waveProp.y * _Time.y );//y is waveSpeed
				float amplitude = waveProp.z / frequency;//Steepness over frequency

				_point.y = randomNum * amplitude * sin(factor);//z is Steepness

				return float3(0,0,_point.y);
			}
			//Old model for the wave splash effect
			float3 OldWave2DSplash(float3 waveProp, float3 _point,float dist,float hitFactor){
				//Everything here is like the previous function
				float frequency = 2 * PI / waveProp.x; //x is waveLength
				float factor = frequency * (_point.x  - waveProp.y * _Time.y);//y is waveSpeed
				float amplitude = waveProp.z / frequency;//Steepness over frequency
				//To calculate the splashEffect at this particular point, we divide the effect strength by the cubic distance
				//The effect strength is in the range [0,1], so to get a result that is in the same range we add 1 to the distance
				//We also multiplay the distance by a spread factor, which specifies how spread the hit effect is
				float splashEffect = abs(hitFactor) / (_hitEffectSpread * (dist  *dist *dist) + 1);
				//We multiply the effect by the amplitude and the sin factor
				_point.y = splashEffect * amplitude * sin(factor);//z is Steepness

				return float3(0,0,_point.y);
			}
			//This is a new model for teh splash wave effect
			//Please see this to understand the wave equation: https://www.desmos.com/calculator/iy2tnqjesg
			float3 Wave2DSplash(float4 waveProp, float3 _point,float4 hitProp){
				//Amplitude
				float amplitude = waveProp.z;
				float dist = abs(hitProp.x - _point.x);
				//We use a custom timer to make sure it starts at 0
				float time = hitProp.w;
				float waveDist = hitProp.z * waveProp.w;//How much distance has the wave crossed: shift * dist
				float shiftedDist = dist - waveDist;
				float cosValue = cos(shiftedDist*waveProp.x  -  waveProp.y * time);
				
				//First wave:
				_point.y =  amplitude * cosValue //You can multiply by cosValue again here to get a wave without depth (no holes)
					* hitProp.y / (_hitEffectSpread * shiftedDist * shiftedDist + 1);
				//Compute the distance assuming the left direction
				shiftedDist = dist + waveDist;
				cosValue = cos(shiftedDist*waveProp.x +  waveProp.y * time);
				//Add Second wave
				_point.y += amplitude * cosValue //You can multiply by cosValue again here to get a wave without depth (no holes)
						* hitProp.y / (_hitEffectSpread * shiftedDist * shiftedDist + 1);
				_point.y /= 2;//Divide the resulting amplitude by 2, since we are summing two waves of amplitude A.
				return float3(0,0,_point.y);
			}

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				output.texCoord = input.texCoord;
				//Apply flow to the texture - make it move
				_MainTex_ST.z += _Time * _FlowSpeedDir.x;
				_MainTex_ST.w += _Time * _FlowSpeedDir.y;

				output.texCoord.xy =  input.texCoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;  //TRANSFORM_TEX(input.uv_MainText, _MainTex);
                
				float noiseSample = tex2Dlod(_NoiseTex, float4(input.texCoord.xy, 0, 0));
				//Apply wave animation
				input.vertex.xyz += Wave2D(_WaveA,input.vertex,noiseSample);
				input.vertex.xyz += Wave2D(_WaveB,input.vertex,noiseSample);
				input.vertex.xyz += Wave2D(_WaveC,input.vertex,noiseSample);
				
				
				//Apply water Splash(s)
				float n = 1;//Count of splashes, used to average them. Initialize to 1 to avoid dividing by 0.
				float3 compinedSplashes  = float3(0,0,0);//Init splashes combined
				for(uint w = 0; w < SplashesArray.Length; w++){ //For each possible splash
					//Add 1 if the splash hit effect(strength) value is greater than 0. See step() documentation for details
					n += 1 - step(0,SplashesArray[w].y);
					//Add splashes from Waves A and B. Provide the distance and the splash hit effect(strength)
					compinedSplashes += Wave2DSplash(_WaveSplash,input.vertex,SplashesArray[w]);
					//You can add more waves here:
					//compinedSplashes += Wave2DSplash(_WaveSplashB,input.vertex,SplashesArray[w]);
				}
				//Since we initialied it to 1, we need to subtract 1 from it in case it became greater than 1
				n -= (1 - step(0,n));
				//Average all the splashes
				compinedSplashes *= 1/n;
				//Cap the maximum height and depth
				compinedSplashes.y = clamp(compinedSplashes.y,-_WaveSplash.z,_WaveSplash.z);
				//Add the splashes positions to the current vertex
				input.vertex.xyz += compinedSplashes;
				//From object space to clip space. See rendering pipelines for details
				output.pos = UnityObjectToClipPos(input.vertex);
				return output;
			}		
			//This is for the Fade Effect. 
			//It calculates the current alpha value of the supplied coordinate (related to the texture)
			float getAlpha(float texcoordY){
				if(_Fade == 0)
					return 1;
				//Get the percentage of the y-coordinate related to the specified fade start and end.
				//Clamp makes sure the percent is between 0 and 1. because the calculation may produce a negative result.
				float percent = clamp(((1 - texcoordY) - _FadeEnd) / (_FadeOrigin - _FadeEnd),0,1);
				//Linear interpolation between the start and end alpha using the percentage.
				return percent*_StartAlpha + (1-percent)*_EndAlpha;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				// sample texture for color
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);
				
				float3 rgb = albedo.rgb * _Color.rgb;
				return float4(rgb, _Color.a);
			}
			ENDCG
		}
    }
}
