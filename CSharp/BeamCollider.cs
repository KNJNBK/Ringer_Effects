using UnityEngine;

public class BeamCollider : MonoBehaviour
{
    private Collider2D _collider;

    [SerializeField]
    private BeamController _controller;

    void Awake()
    {
        _collider = this.GetComponent<Collider2D>();
        if (_collider == null)
        {
            Debug.LogError("No Collider2D component found on beam collider object!");
        }
        if (_controller == null)
        {
            Debug.LogError("No BeamController found, set the serialized field!");
        }
    }

    private void OnTriggerEnter2D(Collider2D other)
    {
        Player player = other.GetComponent<Player>();
        if (player != null && player.TeamType != _controller.Owner.TeamType)
        {
            Debug.Log("<Color=green>Beam hit on player!</Color>");
            _controller.SetDistance((other.transform.position - _controller.transform.position).magnitude);
            player.Stan();
        }
        else if (player != null && player.TeamType == _controller.Owner.TeamType)
        {
            Debug.Log("<Color=yellow>Beam hit on friendly player!</Color>");
        }
        else
        {
            Debug.Log("<Color=red>Beam hit on non-player object!</Color>");
            _controller.SetDistance((other.transform.position - _controller.transform.position).magnitude);
        }
    }
}
