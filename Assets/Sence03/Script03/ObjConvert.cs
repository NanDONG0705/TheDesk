using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjConvert : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    private void OnTriggerEnter(Collider other)
    {
        other.GetComponent<ObjectMove>().enabled = false;
        other.GetComponent<Rigidbody>().isKinematic = false;
        other.GetComponent<Rigidbody>().useGravity = true;
        
    }
}
