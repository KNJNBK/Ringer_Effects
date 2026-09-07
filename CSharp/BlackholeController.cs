using UnityEngine;
using LitMotion;
using System.Collections;
using VContainer;
using CharacterTypeEnums;

[System.Serializable]
public struct BlackholeColorSetting
{
    [SerializeField]
    private TeamType _teamType;
    public readonly TeamType TeamType => _teamType;

    [SerializeField]
    private Color _color1;
    public readonly Color Color1 => _color1;

    [SerializeField]
    private Color _color2;
    public readonly Color Color2 => _color2;
}

class BlackholeController : SkillObject
{
    [Inject]
    private PlayerHandles _playerHandles;
    [SerializeField]
    private float _scaleAnimationPeriod = 0.5f;
    private float _scale = 1.0f;

    [SerializeField]
    private Renderer _renderer;
    private Material _material;

    [SerializeField]
    private float _gravityScale = 1f;

    [SerializeField]
    private float _massPuck = 1f;
    [SerializeField]
    private float _massPlayer = 1f;
    [SerializeField]
    private float _massBlackhole = 100f;

    [SerializeField]
    private BlackholeColorSetting[] _blackholeColorSettings;

    private Rigidbody2D _puckRB;

    private BHScale Scale;

    private bool ready = false;

    private bool gravity = false;

    private int _color1PropId;
    private int _color2PropId;

    class BHScale
    {
        public float Scale;
    }

    protected override void Initialize()
    {
        _color1PropId = Shader.PropertyToID("_Color1");
        _color2PropId = Shader.PropertyToID("_Color2");

        for (int i = 0; i < _blackholeColorSettings.Length; i++)
        {
            if (_blackholeColorSettings[i].TeamType == Owner.TeamType)
            {
                _material.SetColor(_color1PropId, _blackholeColorSettings[i].Color1);
                _material.SetColor(_color2PropId, _blackholeColorSettings[i].Color2);
            }
        }
    }

    private void ScaleUpAnimation(float period)
    {
        Scale.Scale = 0f;
        LMotion.Create(100f, 2.5f, period).WithEase(Ease.OutQuart).Bind(Scale, (x, Scale) => Scale.Scale = x);
    }

    private void ScaleDownAnimation(float period)
    {
        LMotion.Create(2.5f, 100f, period).WithEase(Ease.InQuart).Bind(Scale, (x, Scale) => Scale.Scale = x);
    }

    private float ComputeGravityMagnitude(float distance, float targetMass)
    {
        float closeProximityAdjustment = Mathf.SmoothStep(0, 3f, distance);
        distance = Mathf.Max(distance, 0.1f);
        float magnitude = Mathf.Min(_gravityScale * _massBlackhole * targetMass / (distance * distance), 15f);
        return magnitude * closeProximityAdjustment;
    }

    private IEnumerator BeginLifetime(float lifetimeDuration)
    {
        this.transform.rotation = Quaternion.identity;
        Scale = new BHScale();


        //TODO: これはあまりよくないのでいつか修正する
        Puck puck = FindFirstObjectByType<Puck>();

        if (puck == null)
        {
            Debug.LogWarning("BlackholeController: Could not find Puck!");
            yield break;
        }

        _puckRB = puck.GetComponent<Rigidbody2D>();
        if (_puckRB == null)
        {
            Debug.LogError("BlackholeController: Could not find puck's Rigidbody2D Component!");
        }

        if (_material == null)
        {
            Debug.LogError("No material found for blackhole!");
        }

        ready = true;

        ScaleUpAnimation(0.5f);
        yield return new WaitForSeconds(0.5f);
        //アニメーション終了したら重力効果を有効にする
        gravity = true;
        yield return new WaitForSeconds(lifetimeDuration);
        ScaleDownAnimation(0.5f);
        yield return new WaitForSeconds(0.5f);
        gravity = false;
    }

    private void Awake()
    {
        StartCoroutine(BeginLifetime(15f));
        _material = _renderer.material;
    }

    private void Update()
    {
        if (Owner == null)
        {
            Debug.LogError("BlackholeController: Owner is null!");
        }
        if (ready)
        {
            _material.SetFloat("_TotalScale", Scale.Scale);
        }
    }

    private void FixedUpdate()
    {
        if (gravity)
        {
            if (_puckRB != null)
            {
                Vector2 relativeDisplacement = this.transform.position - _puckRB.transform.position;
                float magnitude = ComputeGravityMagnitude(relativeDisplacement.magnitude, _massPuck);
                _puckRB.AddForce(relativeDisplacement.normalized * magnitude);
            }

            if (_playerHandles != null)
            {
                for (int i = 0; i < _playerHandles.handles.Length; i++)
                {
                    if (_playerHandles.handles[i] != null)
                    {
                        Player player = _playerHandles.handles[i];
                        if (player != null && player.TeamType != Owner.TeamType)
                        {
                            Vector2 relativeDisplacement = this.transform.position - player.transform.position;
                            float magnitude = ComputeGravityMagnitude(relativeDisplacement.magnitude, _massPlayer);
                            player.SetAcceleration(relativeDisplacement.normalized * magnitude);
                        }
                        else
                        {
                            Debug.LogWarning($"BlackholeController: Player handle at index {i} is null.");
                        }
                    }
                    else
                    {
                        Debug.LogWarning($"BlackholeController: Player handle at index {i} is null.");
                    }
                }
            }
            else
            {
                Debug.LogWarning("BlackholeController: PlayerHandles reference is null.");
            }
        }
    }
}
