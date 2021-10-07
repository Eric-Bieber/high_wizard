class FirewallAura : ICompositeActorSkill
{
	UnitPtr m_unit;
	CompositeActorBehavior@ m_behavior;

	ActorBuffDef@ m_buff;
	int m_freq;
	int m_range;
	bool m_friendly;
	
	int m_timer;
	array<ISkillConditional@>@ m_conditionals;
	
	array<UnitPtr>@ m_targets;

	bool active = false;

	int distance = 3;
	
	FirewallAura(UnitPtr unit, SValue& params)
	{
		m_unit = unit;
	
		@m_buff = LoadActorBuff(GetParamString(unit, params, "buff", true));
		m_freq = GetParamInt(unit, params, "freq", true, 1000);
		m_range = GetParamInt(unit, params, "range", true, 150);
		m_friendly = GetParamBool(unit, params, "friendly", false, true);
		m_timer = randi(m_freq);
		
		@m_conditionals = LoadSkillConditionals(unit, params);
	}
	
	void Initialize(UnitPtr unit, CompositeActorBehavior& behavior, int id)
	{
		@m_behavior = behavior;		
	}

	void Save(SValueBuilder& builder)
	{
	}

	void Load(SValue@ sval)
	{
	}

	vec3 findDisplacement(float dir) {
		// S
		if (dir >= 1.18 && dir < 1.96) {
			return vec3(0, -distance, 0);
		}

		// SW
		if (dir >= 1.96 && dir < 2.75) {
			return vec3(distance, -distance, 0);
		}
		
		// W
		if (dir >= 2.75 || dir < -2.75) {
			return vec3(distance, 0, 0);
		}

		// NW
		if (dir >= -2.75 && dir < -1.96) {
			return vec3(distance, distance, 0);
		}

		// N
		if (dir >= -1.96 && dir < -1.18) {
			return vec3(0, distance, 0);
		}

		// NE
		if (dir >= -1.18 && dir < -.38) {
			return vec3(-distance, distance, 0);
		}

		// E
		if (dir >= -.38 && dir < .39) {
			return vec3(-distance, 0, 0);
		}

		// SE
		if (dir >= .39 && dir < 1.18) {
			return vec3(-distance, -distance, 0);
		}	
		return vec3(0,0,0);
	}
	
	void Update(int dt, bool isCasting)
	{
		@m_targets = g_scene.FetchActorsWithOtherTeam(m_behavior.Team, xy(m_unit.GetPosition()), m_range);
		for (uint i = 0; i < m_targets.length(); i++) 
		{
			if (m_targets[i] != m_unit) {
				auto actor = cast<Actor>(m_targets[i].GetScriptBehavior());

				auto behavior = cast<CompositeActorBehavior>(actor);
				if (behavior.m_target !is null){
					vec3 dir = behavior.m_target.m_unit.GetPosition() - m_targets[i].GetPosition();
					float m_dir = atan(dir.y, dir.x);
					vec3 displacement = findDisplacement(m_dir);
					
					m_targets[i].SetPosition(m_targets[i].GetPosition() + displacement);
				}

				actor.ApplyBuff(ActorBuff(m_behavior, m_buff, 1.0f, false));
			}
		}
	}
	
	void OnDamaged() {}
	void OnDeath() {}
	void OnCollide(UnitPtr unit, vec2 normal) {}
	void OnSpawn() {}
	void Destroyed() {}
	void NetUseSkill(int stage, SValue@ param) {}
	bool IsCasting() { return false; }
	void CancelSkill() {}
}
