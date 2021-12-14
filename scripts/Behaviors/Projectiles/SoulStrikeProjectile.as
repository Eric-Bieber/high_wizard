class SoulStrikeProjectile : RayProjectile
{
//CONSTANTS
	int SEEKING_UPDATE_TIME = 1;
	//int SEEKING_DISTANCE = 1000;
	float TURN_SPEED_STANDARD = 0.47;
	float TURN_SPEED_CLOSE = 3;
	int DISTANCE_THRESHOLD_CLOSE = 10;
	
//Variables
	int v_seekingC = 0;

	UnitPtr m_target;

	string fade_fx;

	SoundEvent@ m_sound;

//Constructor
	SoulStrikeProjectile(UnitPtr unit, SValue& params)
	{
		//Parent Constructor (anim)
		super(unit, params);
		fade_fx = GetParamString(unit, params, "fade-fx", false);
		@m_sound = Resources::GetSoundEvent(GetParamString(unit, params, "snd", false));
		
		//Overwrite
		m_seekTurnSpeed = TURN_SPEED_STANDARD;
		m_seeking = true;
		m_ttl = 700;
		m_speed = 8;
	}

	void Initialize(Actor@ owner, vec2 dir, float intensity, bool husk, Actor@ target, uint weapon) override
	{
		PlaySound3D(m_sound, m_unit.GetPosition());
		RayProjectile::Initialize(owner, dir, intensity, husk, target, weapon);
	}

	void setTarget(UnitPtr target) {
		m_target = target;
	}

	void Collide(UnitPtr unit, vec2 pos, vec2 normal) override
	{
		//if (!ShouldCollide(unit))
		//	return;
		
		HitUnit(unit, pos, normal, m_selfDmg, m_bounceOnCollide);
	}
	
//Overrides
	void Update(int dt) override
	{
		v_seekingC -= dt;
		if (v_seekingC < 0) {
			v_seekingC = SEEKING_UPDATE_TIME;
			SetSeekTarget(m_target);
		}

		if (!m_target.IsValid() || m_target.IsDestroyed()) {
			Destroy();
		}

		vec2 position = xy(m_unit.GetPosition());
		float distance = distsq(xy(m_target.GetPosition()), position);
		if (sqrt(distance) <= DISTANCE_THRESHOLD_CLOSE)
			m_seekTurnSpeed = TURN_SPEED_CLOSE;
		else
			m_seekTurnSpeed = TURN_SPEED_STANDARD;

		UpdateSeeking(m_dir, dt);
		
		vec2 from = m_pos;
		m_pos += m_dir * m_speed * dt / 33.0;
	
		array<RaycastResult>@ results = g_scene.Raycast(from, m_pos, ~0, RaycastType::Shot);
		for (uint i = 0; i < results.length(); i++)
		{
			RaycastResult res = results[i];
			if (!HitUnit(res.FetchUnit(g_scene), res.point, res.normal, m_selfDmg, false))
				return;
				
			if (m_unit.IsDestroyed())
				return;
		}

		m_unit.SetPosition(m_pos.x, m_pos.y, 0, true);
		PlayEffect(fade_fx, m_pos, m_effectParams);		

		UpdateSpeed(m_dir, dt);

		ProjectileBase::Update(dt);
	}
	
//External
	void AddEffect(IEffect@ effect)
	{
		m_effects.insertLast(effect);
	}
}