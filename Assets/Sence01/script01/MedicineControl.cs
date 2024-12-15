using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class medicineControl : MonoBehaviour
{

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void UnParent()
    {
        this.transform.localScale = new Vector3(3f, 3f, 3f);
        this.transform.SetParent(null);
        
        
    }



    public void MatchTheSize()
    {
        
        
    }
}
