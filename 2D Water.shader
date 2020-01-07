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
		_WaveSplash("Wave Splash (Length, Speed, Steepness)",Vector) = (1,1,1)
		_WaveSplashB("Wave Splash B (",Vector) = (1,1,1)
		_hitEffectSpread("Hit Spread (0.001 means maximum spread)", Range(0.001,1)) = 0.25 
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

			float map(float value, float min1, float max1, float min2, float max2)
			{
				// Convert the current value to a percentage
				//..percentage of how much close is it to max1 starting from min1
				float perc = (value - min1) / (max1 - min1);
				
				//Now, since percentage should be maintained, we get: perc = (value2 - min2) / (max2 - min2)
				//Rearranging, we get the desired value
				return  perc * (max2 - min2) + min2;
			}

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

				return float3(0,_point.y,0);
			}
			float3 Wave2DSplash(float3 waveProp, float3 _point,float dist,float hitFactor){
				
				float offset = _point.x;
				float frequency = 2 * PI / waveProp.x; //x is waveLength
				float factor = frequency * (offset  - waveProp.y * _Time.y);//y is waveSpeed
				float amplitude = waveProp.z / frequency;//Steepness over frequency

				float splashEffect = abs(hitFactor) / (_hitEffectSpread * (dist  *dist *dist) + 1);

				_point.y = splashEffect * amplitude * sin(factor);//z is Steepness

				return float3(0,_point.y,0);
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
				
				
				//Apple water Splash(s)
				float n = 1;//Count of splashes, used to average them. Initialize to 1 to avoid dividing by 0.
				float3 compinedSplashes  = float3(0,0,0);//Init splashes combined
				for(uint w = 0; w < SplashesArray.Length; w++){ //For each possible splash
					//Get the distance of the splash hit position to this vertex
					float dist = abs(SplashesArray[w].x - input.vertex.x);
					//Add 1 if the splash hit effect(strength) value is greater than 0. See step() documentation for details
					n += 1 - step(0,SplashesArray[w].y);
					//Add splashes from Waves A and B. Provide the distance and the splash hit effect(strength)
					compinedSplashes += Wave2DSplash(_WaveSplash,input.vertex,dist,SplashesArray[w].y);
					compinedSplashes += Wave2DSplash(_WaveSplashB,input.vertex,dist,SplashesArray[w].y);
				}
				//Since we initialied it to 1, we need to subtract 1 from it in case it became greater than 1
				n -= (1 - step(0,n));
				//Average all the splashes
				compinedSplashes *= 1/n;
				//Add the splashes positions to the current vertex
				input.vertex.xyz += compinedSplashes;
				//From object space to clip space. See rendering pipelines for details
				output.pos = UnityObjectToClipPos(input.vertex);
				return output;
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