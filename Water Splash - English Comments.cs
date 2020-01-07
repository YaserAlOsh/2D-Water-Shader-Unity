using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterSplash : MonoBehaviour
{
    //The plane mesh object
    [SerializeField]
    MeshRenderer waterPlane;
    //An optional small interval between each wave. Leave 0 to support multiple waves at the same time
    [SerializeField]
    float timeBetweenSplashes = 0.25f;

    [Tooltip("How much time should the hit of an object onto the water take till settling. Changes based on the object's speed")]
    [SerializeField]
    float hitMinimumTime, hitMaximumTime;
    //السرعة الأدنى التي بعدها تبدأ الأجسام الواقعة في الماء في تسبب موجات
    //والسرعة القصوى التي عندها تتسب الأجسام بأقوى موجة ممكن
    [Tooltip("The minimum speed of rigidbodies falling on water that causes splashes. And the speed which causes maximum hit effect")]
    [SerializeField]
    float objSpeedMinHit, objSpeedMaxHit;

    [Tooltip(" How much time the splash need to fully show up")]
    [Range(0,0.5f)]
    [SerializeField]
    float hitEffectTimePercentage;
    [Tooltip("The name of the array set in the shader")]
    [SerializeField]
    string splashesVectorArrayName = "SplashesArray";
    //أقصى عدد ممكن من الأمواج في الوقت نفسه
    //Shader
    
    يجب أن يكون أقل من أو يساوي المصفوفة في  الـ
    [Tooltip("The maximum count of splashes occuring at the same time. Should be less than or equal to the number set in the shader")]
    [SerializeField]
    
    int maxHits = 10;

    /// <summary>
    /// An array containing info of each splash
    /// </summary>
    SplashInfo[] splashes;
    /// <summary>
    ///An array of vectors that have the splash position in x, and splash effect(Strength) in y
    /// </summary>
    Vector4[] splashesVector;
    
    // Start is called before the first frame update
    void Start()
    {
        //Initialize default values
        splashes = new SplashInfo[maxHits];
        splashesVector = new Vector4[maxHits];
        for(int i =0; i < maxHits; i++)
        {
            splashes[i] = new SplashInfo();
            splashesVector[i] = new Vector4();
        }
        //Set the array for the material
        MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
        materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
        waterPlane.SetPropertyBlock(materialPropertyBlock);
    }

   
    //Info about each splash
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
        //For each splash
        for(int s =0; s <splashes.Length; s++)
        {
            //If there is a splah happening through this item
            if (splashes[s].started)
            {
                SplashInfo splashInfo = splashes[s];
                ///Calculate interpolation value
                float t = (Time.time - splashInfo.startTime) / splashInfo.period;
                ///Current effect strength based on time
                float currVal = Mathf.Lerp(splashInfo.startValue, splashInfo.targetValue, t);
                ///Set the effect strength
                splashesVector[s].y = currVal;
                //Update the array in the material
                MaterialPropertyBlock materialPropertyBlock = new MaterialPropertyBlock();
                materialPropertyBlock.SetVectorArray(splashesVectorArrayName, splashesVector);
                waterPlane.SetPropertyBlock(materialPropertyBlock);
                if (t >= 1)
                {
                    //Settle the wave
                    if (!splashInfo.doReverse)
                    {
                        //Set the current values, time, effech strength, and period
                        splashInfo.startTime = Time.time;
                        splashInfo.startValue = splashInfo.targetValue;
                        splashInfo.targetValue = 0;
                        splashInfo.period = splashInfo.period / hitEffectTimePercentage * (1 - hitEffectTimePercentage);
                        splashInfo.doReverse = true;
                    }
                    else
                    {
                        //Splash ended
                        splashInfo.started = false;
                        splashInfo.doReverse = false;
                    }
                }
            }
        }
    }


    int currentEmptyIndex = 0;
    float lastSplashTime = -1; //Init to -1 to make sure splash works on first frame.
    void OnTriggerEnter2D(Collider2D other) {
        if (Time.time - lastSplashTime < timeBetweenSplashes)
            return;
        lastSplashTime = Time.time;
        //Make sure it is a rigidbody
        if (!other.GetComponentInChildren<Rigidbody2D>())
            return;
        //Calculate local position of the hit
        Vector3 localSpace = other.transform.position - waterPlane.transform.position;
        float xAxis = localSpace.x / waterPlane.transform.localScale.x;
        //Calculate hit effect strength based on the rigidbody's speed
        float speed = other.GetComponentInChildren<Rigidbody2D>().velocity.magnitude;
        float speedInterpValue = Mathf.InverseLerp(objSpeedMinHit, objSpeedMaxHit, speed);
        //Calculate the period of the effect based on the effect strength
        float resultantHitTime = Mathf.Lerp(hitMaximumTime, hitMinimumTime, speedInterpValue);

        //If next index of the array is used
        if (currentEmptyIndex >= splashes.Length || (currentEmptyIndex < splashes.Length && splashes[currentEmptyIndex].started))
        {
            currentEmptyIndex = FindSuitableArrayPosition();

        }
        //If all indexes are used (Look at the function FindSuitableArrayPosition down)
        if (currentEmptyIndex == -1)
        {
            currentEmptyIndex = 0;
            return;
        }
        
        //Set splash info values: start time, start and target value, period
        SplashInfo splashInfo = splashes[currentEmptyIndex];
        splashInfo.startValue = 0 ;
        splashInfo.targetValue = speedInterpValue;
        splashInfo.startTime = Time.time;
        splashInfo.started = true;
        splashInfo.period = resultantHitTime * hitEffectTimePercentage;
        //Set the position of the splash hit
        splashesVector[currentEmptyIndex].x = xAxis;
        // Update the array in the material
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
