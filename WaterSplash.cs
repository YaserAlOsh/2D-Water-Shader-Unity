﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterSplash : MonoBehaviour
{
    //جسم السطح المستوي
    [SerializeField]
    MeshRenderer waterPlane;
    //اختياري: مدة قصيرة بين موجة وأخرى. ابقيه 0 إذا أردت دعم أكثر من موجة في الوقت ذاته
    [SerializeField]
    float timeBetweenSplashes = 0.25f;

    [Tooltip("How much time should the hit of an object onto the water take till settling")]
    // كم من الوقت تحتاجه الموجة بعد وقوع جسم في الماء حتى تستقر
    //تتغير المدة من حد أدنى لأقصى بناءً على سرعة الجسم
    [SerializeField]
    float hitMinimumTime, hitMaximumTime;
    //السرعة الأدنى التي بعدها تبدأ الأجسام الواقعة في الماء في تسبب موجات
    //والسرعة القصوى التي عندها تتسب الأجسام بأقوى موجة ممكن
    [SerializeField]
    float objSpeedMinHit, objSpeedMaxHit;

    /// كم من الوقت منذ اصطدام جسم بالماء تحتاجه الموجة للظهور
    [Range(0,0.5f)]
    [SerializeField]
    float hitEffectTimePercentage;
    //Shaderاسم المصفوفة المعين في الـ
    [SerializeField]
    string splashesVectorArrayName = "SplashesArray";
    //أقصى عدد ممكن من الأمواج في الوقت نفسه
    //Shaderيجب أن يكون أقل من أو يساوي المصفوفة في  الـ
    [SerializeField]
    int maxHits = 10;

    /// <summary>
    /// مصفوفة تحتوي على معلومات عن كل تموجات التصادمات
    /// </summary>
    SplashInfo[] splashes;
    /// <summary>
    ///مصفوفة مواقع وقوع الأجسام في الماء وقوة تأثيرها
    /// </summary>
    Vector4[] splashesVector;
    // Start is called before the first frame update
    void Start()
    {
        //نهيئ جميع المصفوفات بالقيم الافتراضية
        splashes = new SplashInfo[maxHits];
        splashesVector = new Vector4[maxHits];
        for(int i =0; i < maxHits; i++)
        {
            splashes[i] = new SplashInfo();
            splashesVector[i] = new Vector4();
        }
        //Material نعين المصفوفة للـ 
        MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
        materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
        waterPlane.SetPropertyBlock(materialPropertyBlock);
    }

   
    //معلومات عن كل تموج واصطدام
    class SplashInfo{
        public float splashPosition;
        public float splashEffect;
        public float startTime;
        public float period;
        public bool started, doReverse;
        public float startValue, targetValue;
    }

   
    // Update is called once per frame
    void Update()
    {
        //لكل تموج
        for(int s =0; s <splashes.Length; s++)
        {
            //إذا كان التموج في هذه الخانة قد بدأ
            if (splashes[s].started)
            {
                SplashInfo splashInfo = splashes[s];
                //نحسب زمن الاستقراء الحالي
                float t = (Time.time - splashInfo.startTime) / splashInfo.period;
                //قيمة التأثير الحالية بناءً على الزمن
                float currVal = Mathf.Lerp(splashInfo.startValue, splashInfo.targetValue, t);
                //نعين قيمة التأثير
                splashesVector[s].y = currVal;
                // Materialتحديث المصفوفة الموجودة في الـ
                MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
                materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
                waterPlane.SetPropertyBlock(materialPropertyBlock);
                if (t >= 1)
                {
                    //إعادة استقرار الموجة
                    if (!splashInfo.doReverse)
                    {
                        //تحديد المتغيرات الحالية من الزمن وقيمة التأثير الحالية والمدة
                        splashInfo.startTime = Time.time;
                        splashInfo.startValue = splashInfo.targetValue;
                        splashInfo.targetValue = 0;
                        splashInfo.period = splashInfo.period / hitEffectTimePercentage * (1 - hitEffectTimePercentage);
                        splashInfo.doReverse = true;
                    }
                    else
                    {
                        //إنهاء الموجة بعد استقرارها
                        splashInfo.started = false;
                        splashInfo.doReverse = false;
                    }
                }
            }
        }
    }


    int currentEmptyIndex = 0;
    float lastSplashTime = -1; // نعينه ب 1- لنتأكد أن الموجة تعمل من المرة الأولى
    void OnTriggerEnter2D(Collider2D other) {
        if (Time.time - lastSplashTime < timeBetweenSplashes)
            return;
        lastSplashTime = Time.time;
        //نتاكد أن الجسم الواقع في الماء يتحرك فيزيائيًا
        if (!other.GetComponentInChildren<Rigidbody2D>())
            return;
        //نحسب الموقع للاصطدام بالنسبة لمركز كائن الماء
        Vector3 localSpace = other.transform.position - waterPlane.transform.position;
        float xAxis = localSpace.x / waterPlane.transform.localScale.x;
        //نحسب قيمة التأثير بناءً على سرعة الجسم
        float speed = other.GetComponentInChildren<Rigidbody2D>().velocity.magnitude;
        float speedInterpValue = Mathf.InverseLerp(objSpeedMinHit, objSpeedMaxHit, speed);
        //نحسب الزمن المطلوب بناءً على قوة التأثير
        float resultantHitTime = Mathf.Lerp(hitMaximumTime, hitMinimumTime, speedInterpValue);

        //إذا كانت الخانة التالية مستخدمة
        if (currentEmptyIndex >= splashes.Length || (currentEmptyIndex < splashes.Length && splashes[currentEmptyIndex].started))
        {
            currentEmptyIndex = FindSuitableArrayPosition();

        }
        //إذا لم يكن هناك أي خانة فارغة
        if (currentEmptyIndex == -1)
        {
            currentEmptyIndex = 0;
            return;
        }
        //تحديد قيم تأثير التموج من زمن وقوة ومدة
        SplashInfo splashInfo = splashes[currentEmptyIndex];
        splashInfo.startValue = 0 ;
        splashInfo.targetValue = speedInterpValue;
        splashInfo.startTime = Time.time;
        splashInfo.started = true;
        splashInfo.period = resultantHitTime * hitEffectTimePercentage;
        //تعيين موقع تأثير التموج الأصلي
        splashesVector[currentEmptyIndex].x = xAxis;
        // Materialتحديث المصفوفة الموجودة في الـ
        MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
        materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
        waterPlane.SetPropertyBlock(materialPropertyBlock);
        currentEmptyIndex++;

    }

    private int FindSuitableArrayPosition()
    {
        for(int s =0; s <splashes.Length; s++)
        {
            if (!splashes[s].started)
                return s;
        }
        return -1;
    }
    
}
