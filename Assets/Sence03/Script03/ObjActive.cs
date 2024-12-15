using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjActive : MonoBehaviour
{
    private List<GameObject> Objs = new List<GameObject>();
    private int currentIndex = 0;
    public float activationInterval = 1.0f;

    // Start is called before the first frame update
    void Start()
    {
        foreach (Transform child in transform)
        {


            Objs.Add(child.gameObject);
        }

        StartCoroutine(ActivateChildInSequence());
    }

    private IEnumerator ActivateChildInSequence()
    {

        while (true)
        {
            if (currentIndex < Objs.Count) 
            {
                Objs[currentIndex].SetActive(true);
                currentIndex = currentIndex + 1;
            }
            


            yield return new WaitForSeconds(activationInterval);
        }
    }
}
