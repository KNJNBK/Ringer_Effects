using UnityEngine;
using LitMotion;
using LitMotion.Extensions;
using System.Collections;
using CharacterTypeEnums;
using VContainer;

public class BeamController : SkillObject
{
    [SerializeField]
    private Color _blueColor;
    [SerializeField]
    private Color _redColor;
    //メートル毎秒
    [SerializeField]
    private float _velocity = 16f;

    //この時間が経過したらビームが終わる
    [SerializeField]
    private float _duration = 1f;
    private float _countdownTimer = 0f;

    [SerializeField]
    private GameObject _beamMesh;
    [SerializeField]
    private Renderer _renderer;
    private Material _beamMat;

    [SerializeField]
    private GameObject _hitEffectObj;
    [SerializeField]
    private Material _hitEffectMat;

    //当たり判定用のオブジェクト
    [SerializeField]
    private GameObject _colliderObj;
    [SerializeField]
    private BeamCollider _beamColliderController;

    private bool _hit;

    private float _currentDistance;

    private float _distanceToHit;

    private IEnumerator ShootBeam()
    {
        while (Owner == null)
        {
            Debug.LogWarning("BeamController: Owner is null, waiting for assignment...");
            yield return null;
        }
        Debug.Log($"BeamController: Owner assigned as {Owner.name}, starting beam firing sequence.");
        //初期化
        _currentDistance = 0f;
        _countdownTimer = _duration;
        _hit = false;
        _colliderObj.transform.position = this.transform.position;
        _hitEffectObj.SetActive(false);
        if (Owner.TeamType == TeamType.Red)
        {
            Debug.Log("Setting beam colors to red...");
            _beamMat.SetColor("_BeamColor", _redColor);
            _hitEffectMat.SetColor("_BeamHitColor", _redColor);
        }
        else if (Owner.TeamType == TeamType.Blue)
        {
            Debug.Log("Setting beam colors to blue...");
            _beamMat.SetColor("_BeamColor", _blueColor);
            _hitEffectMat.SetColor("_BeamHitColor", _blueColor);
        }
        else
        {
            Debug.LogWarning("No team set for beam! Defaulting to red");
            _beamMat.SetColor("_BeamColor", _blueColor);
            _hitEffectMat.SetColor("_BeamHitColor", _blueColor);
        }
        StartCoroutine(Fire());
    }

    public void SetDistance(float distance)
    {
        _distanceToHit = distance;
        Debug.Log("Beam hit at:" + distance + " meters!");
        _hit = true;
        _hitEffectObj.transform.localPosition += transform.up * _currentDistance;
        _hitEffectObj.SetActive(true);
    }

    private void UpdateCountdownTimer(float deltaTime)
    {
        _countdownTimer -= deltaTime;
    }

    void Awake()
    {
        _beamMat = _renderer.material;

        if (_beamColliderController == null)
        {
            Debug.LogError("No BeamCollider script found in children of BeamController!");
        }
        if (_beamMesh == null)
        {
            Debug.LogError("BeamController: No beam mesh!");
        }
        _beamMesh.transform.localScale = new Vector3(20f, 0f, 1f);
        if (_beamMat == null)
        {
            Debug.LogError("BeamController: No beam material!");
        }
        _beamMat.SetFloat("_EndFadePosition", 0f);

        StartCoroutine(ShootBeam());
    }

    private void ScaleUpAnimation(float period)
    {
        _beamMesh.transform.localScale = new Vector3(20f, 0f, 1f);
        LMotion.Create(0f, 1f, period).WithEase(Ease.OutQuart).BindToLocalScaleY(_beamMesh.transform);
    }

    private void ScaleDownAnimation(float period)
    {
        LMotion.Create(1f, 0f, period).WithEase(Ease.InQuart).BindToLocalScaleY(_beamMesh.transform);
    }

    private void ScaleDownAnimationHit(float period)
    {
        LMotion.Create(3f, 0f, period).WithEase(Ease.InQuart).BindToLocalScaleXYZ(_hitEffectObj.transform);
    }

    private IEnumerator Fire()
    {
        Debug.Log("<Color=green>Firing...</Color>");
        ScaleUpAnimation(0.3f);
        while (_currentDistance < 20f && _countdownTimer > 0f)
        {
            if (!_hit)
            {
                //ビームの先端を前に進める
                Vector3 deltaDisplacement = transform.up * _velocity * Time.deltaTime;
                _colliderObj.transform.position += deltaDisplacement;
                _currentDistance += deltaDisplacement.magnitude;
                Debug.Log(_currentDistance);
                float distanceNormalized = _currentDistance / 20f;
                _beamMat.SetFloat("_EndFadePosition", distanceNormalized);
            }
            else if (_countdownTimer > 0f)
            {
                UpdateCountdownTimer(Time.deltaTime);
                _hitEffectMat.SetFloat("_Brightness", Random.Range(10f, 20f));
            }
            yield return null;
        }
        ScaleDownAnimation(0.5f);
        ScaleDownAnimationHit(0.5f);
    }
}
