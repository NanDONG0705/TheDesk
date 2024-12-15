using UnityEngine;

public class RotationChecker : MonoBehaviour
{

    public GameObject gameObject;
    // Update is called once per frame
    void Update()
    {
        // Call the function to check rotation
        CheckRotation(transform);
    }

    void CheckRotation(Transform objTransform)
    {
        Vector3 rotation = objTransform.eulerAngles;

        // Normalize the angles to be within -180 to 180
        rotation.x = NormalizeAngle(rotation.x);
        rotation.z = NormalizeAngle(rotation.z);

        // Check if the rotation is within the specified ranges
        if (IsWithinRange(rotation.z, 80, 100) || IsWithinRange(rotation.x, 140, 190))
        {
            Debug.Log("ok");
            gameObject.GetComponent<Rigidbody>().isKinematic = false;
           gameObject.transform.SetParent(null);
        }
    }

    // Normalize the angle to be within -180 to 180 degrees
    float NormalizeAngle(float angle)
    {
        while (angle > 180) angle -= 360;
        while (angle < -180) angle += 360;
        return angle;
    }

    // Check if a value is within a specified range
    bool IsWithinRange(float value, float min, float max)
    {
        return value > min && value < max;
    }
}

