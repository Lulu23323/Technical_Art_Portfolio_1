using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// [ExecuteAlways]
// [ExecuteInEditMode]
public class Rotate : MonoBehaviour
{
    public float Speed =1f;

    public bool EnableRotate = false;
    
    public  Vector3 Axis = Vector3.up;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if(EnableRotate)
            transform.Rotate(Axis,Speed*Time.deltaTime);
    }
}