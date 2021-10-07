class HeavensDriveAura : ICompositeActorSkill
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
	
	HeavensDriveAura(UnitPtr unit, SValue& params)
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

		@m_targets = g_scene.FetchActorsWithOtherTeam(m_behavior.Team, xy(m_unit.GetPosition()), m_range);
		active = true;
		
	}

	void Save(SValueBuilder& builder)
	{
	}

	void Load(SValue@ sval)
	{
	}
	
	void Update(int dt, bool isCasting)
	{
		if (active) {
			for (uint i = 0; i < m_targets.length(); i++)
				if (m_targets[i] != m_unit)
					cast<Actor>(m_targets[i].GetScriptBehavior()).ApplyBuff(ActorBuff(m_behavior, m_buff, 1.0f, false));
			active = false;
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
