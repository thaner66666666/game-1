using UnityEngine;

public class CharacterAppearanceManager : MonoBehaviour
{
    private GameObject characterRoot;
    private Material skinMaterial;
    private Material eyeMaterial;

    private void Start()
    {
        characterRoot = new GameObject("CharacterBody");
        characterRoot.transform.SetParent(transform);
        
        // Create materials
        CreateMaterials();
        
        // Build character segments
        CreateHead();
        CreateTorso();
        CreateArms();
        CreateLegs();
    }

    private void CreateMaterials()
    {
        // Skin material
        skinMaterial = new Material(Shader.Find("Standard"));
        skinMaterial.color = new Color(0.8f, 0.65f, 0.5f, 1f);
        
        // Eye material
        eyeMaterial = new Material(Shader.Find("Standard"));
        eyeMaterial.color = Color.blue;
        eyeMaterial.EnableKeyword("_EMISSION");
        eyeMaterial.SetColor("_EmissionColor", Color.blue * 2f);
    }

    private void CreateHead()
    {
        GameObject head = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        head.name = "Head";
        head.transform.SetParent(characterRoot.transform);
        head.transform.localPosition = new Vector3(0, 1.6f, 0);
        head.transform.localScale = new Vector3(0.4f, 0.4f, 0.4f);
        head.GetComponent<Renderer>().material = skinMaterial;

        // Eyes
        CreateEye(-0.1f);
        CreateEye(0.1f);
    }

    private void CreateEye(float xOffset)
    {
        GameObject eye = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        eye.name = "Eye";
        eye.transform.SetParent(characterRoot.transform);
        eye.transform.localPosition = new Vector3(xOffset, 1.65f, 0.15f);
        eye.transform.localScale = new Vector3(0.08f, 0.08f, 0.08f);
        eye.GetComponent<Renderer>().material = eyeMaterial;
    }

    private void CreateTorso()
    {
        // Main torso
        GameObject torso = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        torso.name = "Torso";
        torso.transform.SetParent(characterRoot.transform);
        torso.transform.localPosition = new Vector3(0, 1.1f, 0);
        torso.transform.localScale = new Vector3(0.5f, 0.4f, 0.3f);
        torso.GetComponent<Renderer>().material = skinMaterial;

        // Chest plates (subtle muscle definition)
        CreateMusclePlate(0.15f);
        CreateMusclePlate(-0.15f);
    }

    private void CreateMusclePlate(float xOffset)
    {
        GameObject plate = GameObject.CreatePrimitive(PrimitiveType.Cube);
        plate.name = "ChestPlate";
        plate.transform.SetParent(characterRoot.transform);
        plate.transform.localPosition = new Vector3(xOffset, 1.2f, 0.12f);
        plate.transform.localScale = new Vector3(0.2f, 0.25f, 0.05f);
        plate.GetComponent<Renderer>().material = skinMaterial;
    }

    private void CreateArms()
    {
        CreateArm(0.3f); // Right arm
        CreateArm(-0.3f); // Left arm
    }

    private void CreateArm(float xOffset)
    {
        // Upper arm
        GameObject upperArm = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        upperArm.name = "UpperArm";
        upperArm.transform.SetParent(characterRoot.transform);
        upperArm.transform.localPosition = new Vector3(xOffset, 1.3f, 0);
        upperArm.transform.localScale = new Vector3(0.15f, 0.25f, 0.15f);
        upperArm.GetComponent<Renderer>().material = skinMaterial;

        // Forearm
        GameObject forearm = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        forearm.name = "Forearm";
        forearm.transform.SetParent(characterRoot.transform);
        forearm.transform.localPosition = new Vector3(xOffset, 0.9f, 0);
        forearm.transform.localScale = new Vector3(0.12f, 0.25f, 0.12f);
        forearm.GetComponent<Renderer>().material = skinMaterial;
    }

    private void CreateLegs()
    {
        CreateLeg(0.15f); // Right leg
        CreateLeg(-0.15f); // Left leg
    }

    private void CreateLeg(float xOffset)
    {
        // Upper leg
        GameObject upperLeg = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        upperLeg.name = "UpperLeg";
        upperLeg.transform.SetParent(characterRoot.transform);
        upperLeg.transform.localPosition = new Vector3(xOffset, 0.6f, 0);
        upperLeg.transform.localScale = new Vector3(0.15f, 0.3f, 0.15f);
        upperLeg.GetComponent<Renderer>().material = skinMaterial;

        // Lower leg
        GameObject lowerLeg = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        lowerLeg.name = "LowerLeg";
        lowerLeg.transform.SetParent(characterRoot.transform);
        lowerLeg.transform.localPosition = new Vector3(xOffset, 0.2f, 0);
        lowerLeg.transform.localScale = new Vector3(0.12f, 0.3f, 0.12f);
        lowerLeg.GetComponent<Renderer>().material = skinMaterial;
    }
}
