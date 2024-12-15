using UnityEngine;

public class FadeInMaterial : MonoBehaviour
{
    public float duration = 1.0f; // 渐变持续时间
    public bool fade = false; // 控制透明度变化
    private Renderer rend;
    private Color targetColor;
    private float elapsedTime = 0f;
    public GameObject pencil;
    public GameObject eraser;

    void Start()
    {
        rend = GetComponent<Renderer>();
        targetColor = rend.material.color;
        Color startColor = targetColor;
        startColor.a = 0;
        rend.material.color = startColor;
    }

    void Update()
    {
        if (fade)
        {
            UpdateTransparency();
        }
        else
        {
            ResetFade();
        }
    }

    void UpdateTransparency()
    {
        if (elapsedTime < duration)
        {
            elapsedTime += Time.deltaTime;
            float alpha = Mathf.Clamp01(elapsedTime / duration);
            Color newColor = targetColor;
            newColor.a = alpha;
            rend.material.color = newColor;
        }
    }

    // 重置透明度和时间
    public void ResetFade()
    {
        if (elapsedTime >= duration)
        {
            elapsedTime = 0f;
            Color startColor = targetColor;
            startColor.a = 0;
            rend.material.color = startColor;
        }
       
    }


    private void OnTriggerEnter(Collider other)
    {
        if (other.gameObject == pencil)
        {
            fade = true;
        }

        if (other.gameObject == eraser)
        {
            fade = false ;
        }
    }
}

