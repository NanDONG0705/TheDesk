using UnityEngine;

public class ConveyorBelt : MonoBehaviour
{
    // Speed at which the conveyor belt moves
    public float speed = 0.1f;
    private Renderer conveyorRenderer;

    
    void Start()
    {
        conveyorRenderer = GetComponent<Renderer>();
    }

    void Update()
    {
        // Calculate the offset based on the elapsed time and speed
        float offset = Time.time * speed;

        // Move the texture by setting the vertical offset
        conveyorRenderer.material.SetTextureOffset("_MainTex", new Vector2(0, offset));
    }
}