using UnityEngine;

public class BlackHoleLUTGenerator : MonoBehaviour
{
    [SerializeField]
    int BAKING_RESOLUTION_WIDTH;
    [SerializeField]
    int BAKING_RESOLUTION_HEIGHT;
    [SerializeField]
    float VIEW_ANGLE = 0.0f;
    [SerializeField]
    float ROLL_ANGLE = 0.0f;
    [SerializeField]
    int VIEW_HEIGHT = 1080;
    [SerializeField]
    int VIEW_WIDTH = 1920;
    [SerializeField]
    float BG_Z_DEPTH = 10f;
    [SerializeField]
    float DISTANCE_TO_BH = 10f;
    [SerializeField]
    int MAX_STEP_COUNT = 200;
    [SerializeField]
    //NOTE: こいつの単位は時間だよ
    //単位は光が一メートルを進むのに必要な時間
    //幾何学単位　(Geometrized Units)
    float STEP_SIZE = 1.0f;
    //万有引力定数 (単位G 6.67E-11)
    [SerializeField]
    float G_CONSTANT_NORMALIZED = 1.0f;
    [SerializeField]
    float MASS = 1.0f;
    //使用している時間の単位で光速が１となったので割ることはない
    float EVENT_HORIZON_RADIUS = 0f;
    [SerializeField]
    Vector3 SINGULARITY_POSITION = Vector3.zero;
    [SerializeField]
    float DISK_RADIUS_INNER = 1.5f;
    [SerializeField]
    float DISK_RADIUS_OUTER = 3.0f;
    [SerializeField]
    float DISK_THICKNESS = 0.2f;

    struct Ray3D
    {
        public Vector3 position;
        public Vector3 velocity;
    }

    void Start()
    {
        EVENT_HORIZON_RADIUS = 2 * G_CONSTANT_NORMALIZED * MASS;
        GenerateBlackHoleLUT(BAKING_RESOLUTION_WIDTH, BAKING_RESOLUTION_HEIGHT, "TestBake1");
    }

    public void GenerateBlackHoleLUT(int width, int height, string fileName)
    {
        Texture2D lutTex = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true);
        for (uint h = 0; h < height; h++)
        {
            for (uint w = 0; w < width; w++)
            {
                //Begin Raytracing
                Color data = RayMarch(w, h, width, height);
                lutTex.SetPixel((int)w, (int)h, data);
            }
        }
        lutTex.Apply();

        byte[] bytes = lutTex.EncodeToEXR(Texture2D.EXRFlags.None);

        string path = System.IO.Path.Combine(Application.dataPath, fileName + ".exr");

        System.IO.File.WriteAllBytes(path, bytes);

#if UNITY_EDITOR
        UnityEditor.AssetDatabase.Refresh();
#endif

        Debug.Log($"LUT Successfully Baked and Saved to: {path}");
    }

    Ray3D InitializeRay(float u, float v)
    {
        Ray3D ray;
        //これのアスペクト比がもしテクスチャのアスペクト比とズレたら変に伸びたり圧縮されたりするかも？
        ray.position = new Vector3(u * VIEW_WIDTH, v * VIEW_HEIGHT, -DISTANCE_TO_BH);
        ray.velocity = new Vector3(0f, 0f, 1f);
        //初期位置を回転する。
        Quaternion tiltRotation = Quaternion.Euler(VIEW_ANGLE, 0f, ROLL_ANGLE);
        ray.position = tiltRotation * ray.position;
        //方向だから違うんじゃないと思ったがよく考えたら方向も同じ回転行列をかけばちゃんと正しい回転になるわ。
        ray.velocity = tiltRotation * ray.velocity;

        return ray;
    }

    //背景の平面を通過したかどうかを確認するための関数、Z軸を確認するだけ
    Vector3 BHSpaceToViewPlaneSpace(Vector3 rayBHPos)
    {
        Vector3 viewPlaneSpacePos = Vector3.zero;
        Quaternion tiltRotation = Quaternion.Euler(-VIEW_ANGLE, 0f, -ROLL_ANGLE);
        viewPlaneSpacePos = tiltRotation * rayBHPos;
        return viewPlaneSpacePos;
    }

    Color RayMarch(uint w, uint h, int width, int height)
    {
        Vector2 initialUV = new Vector2(((float)w / (float)(width - 1)) - 0.5f, ((float)h / (float)(height - 1)) - 0.5f);
        Color data = new Color(0, 0, 0, 0);
        Ray3D ray = InitializeRay(initialUV.x, initialUV.y);
        bool hasIntersectedDisk = false;
        for (uint step = 0; step < MAX_STEP_COUNT; step++)
        {
            Vector3 viewPlanePos = BHSpaceToViewPlaneSpace(ray.position);

            if (ray.position.magnitude < EVENT_HORIZON_RADIUS && !hasIntersectedDisk)
            {
                return new Color(0, 0, 0, 1);
            }
            //カメラの方に戻ってきたら
            if (viewPlanePos.z < -BG_Z_DEPTH)
            {
                Vector2 distortedUV = new Vector2(-1 * viewPlanePos.x / VIEW_WIDTH, viewPlanePos.y / VIEW_HEIGHT);
                Vector2 deltaUV = distortedUV - initialUV;
                data.r = deltaUV.x;
                data.g = deltaUV.y;
                break;
            }
            //背景の平面を通過したら
            if (viewPlanePos.z > BG_Z_DEPTH)
            {
                Vector2 distortedUV = new Vector2(viewPlanePos.x / VIEW_WIDTH, viewPlanePos.y / VIEW_HEIGHT);
                Vector2 deltaUV = distortedUV - initialUV;
                data.r = deltaUV.x;
                data.g = deltaUV.y;
                break;
            }
            //降着円盤を通過したら通過した点の極座標を書き込む
            if (!hasIntersectedDisk)
            {
                Vector2 diskIntersect = CheckDisk(ray.position);
                if (diskIntersect.magnitude >= 1.0f)
                {
                    data.b = diskIntersect.x;
                    data.a = diskIntersect.y;
                    hasIntersectedDisk = true;
                    break;
                }
            }
            ray = RK4(ray);
        }
        return data;
    }

    Vector2 CheckDisk(Vector3 position)
    {
        //上下の範囲を確認
        if (position.y > DISK_THICKNESS / 2 || position.y < -DISK_THICKNESS / 2)
        {
            return Vector2.zero;
        }

        Vector2 radial = new Vector2(position.x, position.z);
        float radius = radial.magnitude;

        //降着円盤の半径外かどうかを確認
        if (radius > DISK_RADIUS_OUTER || radius < DISK_RADIUS_INNER)
        {
            return Vector2.zero;
        }

        float normalizedRadius = (radial.magnitude - DISK_RADIUS_INNER) / (DISK_RADIUS_OUTER - DISK_RADIUS_INNER);

        Vector2 normalizedRadial = new Vector2(normalizedRadius * radial.x, normalizedRadius * radial.y);

        return normalizedRadial;
    }

    Vector3 BendAcceleration(Vector3 rayPos, Vector3 blackHolePos, float mass, float g_constant)
    {
        Vector3 toHole = blackHolePos - rayPos;
        float r = toHole.magnitude;
        float r2 = r * r;
        Vector3 newtonian = toHole * mass / (r2 * Mathf.Max(r, 0.001f));

        Vector3 relativistic = toHole * (3.0f * mass * g_constant * g_constant) / (r2 * r2 * Mathf.Max(r, 0.001f));

        return newtonian + relativistic;
    }

    //ルンゲクッタ4
    Ray3D RK4(Ray3D ray)
    {
        float _StepSize = STEP_SIZE;
        float mass = MASS;
        float g_constant = G_CONSTANT_NORMALIZED;
        Vector3 _BlackHolePos = SINGULARITY_POSITION;

        Vector3 p0 = ray.position;
        Vector3 vk0 = BendAcceleration(p0, _BlackHolePos, mass, g_constant);
        Vector3 v0 = ray.velocity;

        Vector3 p1 = p0 + v0 * _StepSize / 2;
        Vector3 vk1 = BendAcceleration(p1, _BlackHolePos, mass, g_constant);
        Vector3 v1 = v0 + vk0 * _StepSize / 2;

        Vector3 p2 = p0 + v1 * _StepSize / 2;
        Vector3 vk2 = BendAcceleration(p2, _BlackHolePos, mass, g_constant);
        Vector3 v2 = v0 + vk1 * _StepSize / 2;

        Vector3 p3 = p0 + v2 * _StepSize;
        Vector3 vk3 = BendAcceleration(p3, _BlackHolePos, mass, g_constant);
        Vector3 v3 = v0 + vk2 * _StepSize;

        Vector3 newVel = v0 + _StepSize / 6 * (vk0 + 2 * vk1 + 2 * vk2 + vk3);
        Vector3 newPos = p0 + _StepSize / 6 * (v0 + 2 * v1 + 2 * v2 + v3);

        ray.velocity = newVel.normalized;
        ray.position = newPos;
        return ray;
    }
}
