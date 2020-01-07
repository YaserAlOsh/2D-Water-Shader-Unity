Shader "Custom/2D Water Arabic Comments"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		//صورة ضجيج - نقاط يختلف لونها بين الأسود والأبيض - تستخدم للعشوائية
		_NoiseTex("Noise Texture (Optional for randomness)", 2D) = "white" {}
	    _FlowSpeedDir("Flow Speed (X,Y)", Vector) = (1,1,0,0)
		//(الموجة الأولى - متجه يحتوي على طول الموجة وسرعتها وارتفاعها (انحدارها
		_WaveA("Wave Properties (Length, Speed, Steepness)",Vector) = (1,1,1)
		//موجة أخرى إضافية
		_WaveB("Wave Properties",Vector) = (1,1,1)
		//موجة أخرى إضافية
		_WaveC("Wave Properties",Vector) = (1,1,1)
		//موجة تفعل فقط عند حدوث اصطدام مع الماء من قبل جسم ماءء
		_WaveSplash("Wave Splash (Length, Speed, Steepness)",Vector) = (1,1,1)
		//موجة اصطدام إضافية
		_WaveSplashB("Wave Splash B (",Vector) = (1,1,1)
		//مدى تمدد موجات الاصطدام
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
			

			//10 هو أقصى عدد ممكن لأمواج الدفقات
			// x سنضع موقع الاصطدام بالماء في المركبة  
			// y وقوة التأثير في المركبة   
			float2 SplashesArray[10]; 
			//ثابت
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

			//دالة تأخذ قيمة وتقوم بمسحها على مجال جديد
			float map(float value, float min1, float max1, float min2, float max2)
			{
				//نحول القيمة المعطاة إلى نسبة بين القيمة الصغرى والعظمى للمجال الأول
				float perc = (value - min1) / (max1 - min1);
				
				//والآن، بما أنه على النسبة أن تبقى ثابتة، فعبر بعض المعادلات نحصل على
				//perc = (value2 - min2) / (max2 - min2)
				//:ثم
				return  perc * (max2 - min2) + min2;
			}

			float3 Wave2D(float3 waveProp, float3 _point, float randomNum){
				//تردد موجة دالة الجيب هي 
				//2pi / الدورة
				//حيث الدورة هو طول الموجة
				float frequency = 2 * PI / waveProp.x; //x => waveLength طول الموجة
				//sin(B(x-c)), 
				//B هو الترددد
				// ولنقلها وتغييرها بشكل مستمر، نعتبر بأنها الزمن. c هي الإزاحة الأفقية 
				//ثم نضربها بالسرعة لكي، بالطبع، نتحكم السرعة
				float factor =   frequency * ( _point.x  - waveProp.y * _Time.y );//y is waveSpeed
				//ارتفاع الموجة هو الحدة على التردد
				float amplitude = waveProp.z / frequency;//Steepness over frequency
				//نضرب الارتفاع بدالة الجيب وبالقيمة العشوائية
				_point.y = randomNum * amplitude * sin(factor);

				return float3(0,_point.y,0);
			}
			float3 Wave2DSplash(float3 waveProp, float3 _point,float dist,float hitFactor){
				//كل شيء هنا مماقل للدالة السابقة
				float frequency = 2 * PI / waveProp.x; //x is waveLength
				float factor = frequency * (_point.x  - waveProp.y * _Time.y);//y is waveSpeed
				float amplitude = waveProp.z / frequency;//Steepness over frequency
				//تأثير التدفق أو الاصطدام نحسبه عبر تقسيم معامل التأثير على مكعب المسافة
				// لذا عندما يكون التأثير أكبر ما يمكن  أي = 1 نحصل على:
				// 1/(x^3) 
				//ونضيف 1 لتجنب القسمة على الصفر
				//معامل التمدد هو مجرد ثابت غير من تمدد الدالة
				float splashEffect = abs(hitFactor) / (_hitEffectSpread * (dist  *dist *dist) + 1);
				//نضرب قيمة التأثير بالارتفاع وبدالة الجيب
				_point.y = splashEffect * amplitude * sin(factor);//z is Steepness

				return float3(0,_point.y,0);
			}

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				output.texCoord = input.texCoord;
				//نضيف تأثير الحركة للصورة عبر جعلها تتموج
				_MainTex_ST.z += _Time * _FlowSpeedDir.x;
				_MainTex_ST.w += _Time * _FlowSpeedDir.y;

				//نقوم بتحويل الإحداثيات من إحدايات الصورة إلى إحداثيات التخطيط
				//التخطيط  = UV Coordinates
				output.texCoord.xy =  input.texCoord.xy * _MainTex_ST.xy + _MainTex_ST.zw; 
                //نجلب قيمة عشوائية من صورة الضجيج
				float noiseSample = tex2Dlod(_NoiseTex, float4(input.texCoord.xy, 0, 0));

				//نطبق حركة الأمواج
				//نستخدم الأمواج الثلاثة الواحدة تلو الأخرى
				input.vertex.xyz += Wave2D(_WaveA,input.vertex,noiseSample);
				input.vertex.xyz += Wave2D(_WaveB,input.vertex,noiseSample);
				input.vertex.xyz += Wave2D(_WaveC,input.vertex,noiseSample);
				
				//نطبق تدفق الاصطدام بالماء
				float n = 1;//عدد التصادمات. يستخدم لحساب المتوسط. نهئينه ب 1 لتجنب القسمة على 0 
				float3 compinedSplashes  = float3(0,0,0);//نهيئ متجه يجمع تأثيرات الاصطدامات كلها

				for(uint w = 0; w < SplashesArray.Length; w++){ //لكل اصطدام محتمل
					//Get the distance of the splash hit position to this vertex
					//نحسب المسافة من موقع الاصطدام إلى موقع الرأس الحالي
					float dist = abs(SplashesArray[w].x - input.vertex.x);
					//نضيف 1 إذا كانت قوة الاصطدام لها قيمة أكبر من الصفر
					//step انظر مراجع الدالة  
					n += 1 - step(0,SplashesArray[w].y);
					//اجمع تأثير الاصطدام عبر محاكاة الموجتان
					//أعطي المسافة وقوة الاصطدام والتأثير
					compinedSplashes += Wave2DSplash(_WaveSplash,input.vertex,dist,SplashesArray[w].y);
					compinedSplashes += Wave2DSplash(_WaveSplashB,input.vertex,dist,SplashesArray[w].y);
				}
				//بما أننا هيئناه بصفر، نطرح 1 منه إذا كان أصبح من 1 
				n -= (1 - step(0,n));
				//احسب متوسط جميع الاصطدامات
				compinedSplashes *= 1/n;
				//اجمع موقع متوسط تأثير الاصطدامات إلى موقع الرأس الحالي
				input.vertex.xyz += compinedSplashes;

				//تحويل من إحداثيات الكائن إلى إحداثيات تخطيط الشاشة
				//تخطيط الشاشة = clip Space
				output.pos = UnityObjectToClipPos(input.vertex);
				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				//أحضر الصورة المعطاة وخزنها في متجه رباعي
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);

				//طبق اللون على الصورة
				float3 rgb = albedo.rgb * _Color.rgb;
				return float4(rgb, _Color.a);
			}

			ENDCG
		}

       
    }
}