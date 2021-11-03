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
	array<UnitPtr>@ m_players;

	bool active = false;

	int distance = 3;

	SoundEvent@ m_sound;

	float m_healthLoss;

	float m_multiplier = 1;
	
	FirewallAura(UnitPtr unit, SValue& params)
	{
		m_unit = unit;
	
		@m_buff = LoadActorBuff(GetParamString(unit, params, "buff", true));
		@m_sound = Resources::GetSoundEvent(GetParamString(unit, params, "snd", false));
		m_freq = GetParamInt(unit, params, "freq", true, 1000);
		m_range = GetParamInt(unit, params, "range", true, 150);
		m_friendly = GetParamBool(unit, params, "friendly", false, true);
		m_timer = randi(m_freq);

		m_healthLoss = GetParamFloat(unit, params, "health-loss", true, 0.05f);
		
		@m_conditionals = LoadSkillConditionals(unit, params);
	}
	
	void Initialize(UnitPtr unit, CompositeActorBehavior& behavior, int id)
	{
		@m_behavior = behavior;		

		@m_players = g_scene.FetchActorsWithTeam(m_behavior.Team, xy(m_unit.GetPosition()), 1000);

		PlaySound3D(m_sound, m_unit.GetPosition());

		m_multiplier = findMultiplier();
	}

	void Save(SValueBuilder& builder)
	{
	}

	void Load(SValue@ sval)
	{
	}

	void Update(int dt, bool isCasting)
	{
		@m_targets = g_scene.FetchActorsWithOtherTeam(m_behavior.Team, xy(m_unit.GetPosition()), m_range);
		
		for (uint i = 0; i < m_targets.length(); i++) 
		{
			if (m_targets[i] != m_unit) {
				auto actor = cast<Actor>(m_targets[i].GetScriptBehavior());
				auto behavior = cast<CompositeActorBehavior>(actor);
				if (behavior.m_target !is null && behavior.m_enemyType != "construct"){
					vec3 dir = behavior.m_target.m_unit.GetPosition() - m_targets[i].GetPosition();
					float m_dir = atan(dir.y, dir.x);
					
					m_targets[i].SetPosition(m_targets[i].GetPosition() + vec3(cos(m_dir), sin(m_dir), 0) * -distance);
				}
				
				actor.ApplyBuff(ActorBuff(m_behavior, m_buff, 1.0f * m_multiplier, false));

				m_behavior.m_hp -= m_healthLoss;
			}
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
				float tempMult = amp.GetChargeValue(true);
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
