﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Curvy" {
    Properties {
        _Color1 ("Color1", Color) = (1,1,1,1)
        _Color2 ("Color2", Color) = (0,0,0,0)
        _VFreq ("VFreq", Range (1,1000)) = 1
		_HFreq ("HFreq", Range (1,1000)) = 1
		_Deg ("Degrees", Range (-45,45)) = 0
		_VAmplitude ("VAmplitude", Range(0, 1)) = 0
		_VNumCycles ("VNumCycles", Range(0, 100)) = 0 
		_VSmooth ("VSmooth", Range(0,1)) = 1
		_HAmplitude ("HAmplitude", Range(0, 1)) = 0
		_HNumCycles ("HNumCycles", Range(0, 100)) = 0 
		_HSmooth ("HSmooth", Range(0,1)) = 1
    }
	SubShader {
		Tags { "RenderType" = "Opaque"}
		Lighting On
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

			fixed4 _Color1;
			fixed4 _Color2;
			float _VFreq;
			float _HFreq;
			float _Deg;
			float _VAmplitude;
			float _VNumCycles;
			float _VSmooth;
			float _HAmplitude;
			float _HNumCycles;
			float _HSmooth;

            struct vertexInput {
                float4 vertex : POSITION;
                float4 texcoord0 : TEXCOORD0;
            };

            struct fragmentInput{
                float4 position : SV_POSITION;
                float4 texcoord0 : TEXCOORD0;
            };

            fragmentInput vert(vertexInput i){
                fragmentInput o;
                o.position = UnityObjectToClipPos (i.vertex);
                o.texcoord0 = i.texcoord0;
                return o;
            }

            fixed4 frag(fragmentInput i) : SV_Target {
                fixed4 color;
				if( _VSmooth == 0 )
				{
					if ( fmod((i.texcoord0.x + (_VAmplitude*2 / (_VNumCycles/10)) * (_VNumCycles/10 - abs(fmod(i.texcoord0.y, 2*_VNumCycles/10) - _VNumCycles/10)))*_VFreq + 0.35, 2.0) <= 1.0 ){
						if ( fmod(i.texcoord0.y*_HFreq,2.0) < 1.0 )
						{
							color = _Color1;
						} else {
							color = _Color2;
						}
					} else {
						if ( fmod(i.texcoord0.y*_HFreq,2.0) > 1.0 )
						{
							color = _Color1;
						} else {
							color = _Color2;
						}
					}
				}
				else if (_VSmooth == 1)
				{
				if ( fmod((i.texcoord0.x + _VAmplitude * sin(_VNumCycles/0.15*i.texcoord0.y - 1.4))*_VFreq + 0.5,2.0) < 1.0 ){
						if ( fmod(i.texcoord0.y*_HFreq,2.0) < 1.0 )
						{
							color = _Color1;
						} else {
							color = _Color2;
						}
					} else {
						if ( fmod(i.texcoord0.y*_HFreq,2.0) > 1.0 )
						{
							color = _Color1;
						} else {
							color = _Color2;
						}
					}
				}
                return color;
            }
            ENDCG
        }
    }
	Fallback "VertexLit"
}