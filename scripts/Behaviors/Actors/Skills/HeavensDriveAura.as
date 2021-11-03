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
	array<UnitPtr>@ m_players;

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
		@m_players = g_scene.FetchActorsWithTeam(m_behavior.Team, xy(m_unit.GetPosition()), 1000);
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
			float multiplier;
			if (m_targets.length() > 0) {
				multiplier = findMultiplier();
			} else
				return;

			for (uint i = 0; i < m_targets.length(); i++) {
				if (m_targets[i] != m_unit) {
					auto behavior = cast<CompositeActorBehavior>(m_targets[i].GetScriptBehavior());
					for (uint j = 0; j < behavior.m_buffs.m_buffs.length(); j++) {
						if(behavior.m_buffs.m_buffs[j].m_def.m_name == "stormgust-freeze") {
							cast<Actor>(m_targets[i].GetScriptBehavior()).ApplyBuff(ActorBuff(m_behavior, m_buff, 2.0f * multiplier, false));
							active = false;
						}
					}
					if (active)
						cast<Actor>(m_targets[i].GetScriptBehavior()).ApplyBuff(ActorBuff(m_behavior, m_buff, 1.0f * multiplier, false));
				}
			}
			active = false;
		}
	}

	float findMultiplier() {
		float mult = 1;
		for (uint j = 0; j < m_players.length(); j++) {
			auto player = cast<PlayerBase>(m_players[j].GetScriptBehavior());
			if (player is null) {
				continue;
			}

			auto amp = cast<Skills::AmplifyMagic>(player.m_skills[6]);
			if (amp !is null) {
				float tempMult = amp.GetChargeValue(false);
				mult =  tempMult > mult ? tempMult : mult;
			}
		}
		return mult;
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
