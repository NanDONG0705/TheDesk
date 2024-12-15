using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class OpenLight : MonoBehaviour
{

    private List<GameObject> lights = new List<GameObject>();

    // Index to track the current active light group
    private int currentIndex = 0;

    // Time interval for switching lights
    public float activationInterval = 1.0f;


    void Start()
    {
        // Add each child GameObject of the parent to the lights list
        foreach (Transform child in transform)
        {
            lights.Add(child.gameObject);
        }

      
        StartCoroutine(ActivateChildInSequence());
    }


    private IEnumerator ActivateChildInSequence()
    {
        while (true)
        {

            print(lights.Count);
            // Play an audio source each time lights are switched
            this.GetComponent<AudioSource>().Play();

            // Deactivate all lights initially
            foreach (GameObject child in lights)
            {
                child.SetActive(false);
            }

            // Activate a group of 4 lights in sequence
            for (int i = 0; i < 4; i++)
            {
                int indexToActivate = (currentIndex + i) % lights.Count;
                lights[indexToActivate].SetActive(true);
            }

            // Update the index to the next group of 4 lights
            currentIndex = (currentIndex + 4) % lights.Count;

            // Wait for the specified interval before switching again
            yield return new WaitForSeconds(activationInterval);
        }
    }
}