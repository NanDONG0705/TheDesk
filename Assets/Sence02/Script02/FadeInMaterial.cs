using UnityEngine;

public class FadeInMaterial : MonoBehaviour
{
    public float duration = 1.0f; // �������ʱ��
    public bool fade = false; // ����͸���ȱ仯
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

    // ����͸���Ⱥ�ʱ��
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

