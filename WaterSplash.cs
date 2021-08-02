using System.Collections;
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
        public bool started, doReverse, move;
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
                //نزيد عداد الزمن الخاص
                splashesVector[s].w = splashesVector[s].w + Time.deltaTime;
                //في هذا النموذج نقوم بإزاحة الموجة إلى الجهتين يدويا
                //إذا بدأنا بالتحريك أو الإزاحة:
                if(splashInfo.move){
                    //إذا لم نبدأ بتهدئة الموجة بعد (انظر الكود الأسفل)
                    if(!splashInfo.doReverse)
                        splashesVector[s].z = Mathf.Lerp(0,.5f,t);//نزيح الموجة تدريجيًا إلى منتصف المسافة (تحدد داخل الشيدر)
                    else//في حال بدأنا بتهدئة أو إيقاف الموجة
                        splashesVector[s].z = Mathf.Lerp(.5f,1f,t);//نزيحها إلى آخر المسافة
                    
                }
                // Materialتحديث المصفوفة الموجودة في الـ
                MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
                materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
                waterPlane.SetPropertyBlock(materialPropertyBlock);
                if (t >= 1)
                {
                    //انتهاء المرحلة الأولى
                    if (!splashInfo.doReverse)
                    {
                        //نبدأ مرحلة تحريك الموجة في الاتجاهين
                        //نبقي على استقرار الموجة
                        if(!splashInfo.move){
                            splashInfo.move=true;
                            //نستخدم الزمن الحالي
                            splashInfo.startTime = Time.time;
                            //نستخدم نصف المدة المحددة
                            //(ملاحظة: المعادلة هذه تحسب الزمن المتبقي بعد انتهاء المرحلة الأولى . يمكن حساب و حفظ قيمته مسبقا بدلا من حسابه هنا)
                            splashInfo.period = 0.5f * splashInfo.period * (1 - hitEffectTimePercentage) / hitEffectTimePercentage;
                            //لا نريد أي تغيير في قوة الموجة في هذه المرحلة
                            splashInfo.startValue = splashInfo.targetValue;
                        }
                        //هنا نوقف الموجة.
                        else{
                            //تحديد المتغيرات الحالية من الزمن وقيمة التأثير الحالية والمدة
                            splashInfo.startTime = Time.time;
                            splashInfo.startValue = splashInfo.targetValue;
                            //نوقف الموجة عبر جعل قوة تأثيرها 0
                            splashInfo.targetValue = 0;
                            //لا حاجة لإعادة حساب الزمن المتبقي في النموذج الجديد
                            //splashInfo.period = splashInfo.period / hitEffectTimePercentage * (1 - hitEffectTimePercentage);
                            splashInfo.doReverse = true;
                        }
                    }
                    else
                    {
                        //نعيد تعيين المتغيرات بعد انتهاء الموجة
                        splashInfo.started = false;
                        splashInfo.doReverse = false;
                        splashInfo.move = false;
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
        //للنموذج الجديد:
        //مدى تمدد الموجة الحالي (أو إزاحتها عن الموقع الأصلي للاصطدام)
        splashesVector[currentEmptyIndex].z = 0;
        //الزمن الحالي. نبدأ بالصفر دائما ليبدأ شكل الموجة في ارتفاع
        splashesVector[currentEmptyIndex].w = 0;
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
