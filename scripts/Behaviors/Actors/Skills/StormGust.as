namespace Skills
{
	class StormGust : ActiveSkill
	{
		UnitProducer@ m_unitProd;
	
		int m_duration;
		int m_durationC;

		bool m_safeSpawning;
		bool m_spawningHusk;
		bool m_needNetSync;

		string m_spawnFx;

		vec2 m_spawnPos;

		int interval = 1000;
		int intervalC;

		int m_numUnits;

		int effectsSpawned;

		string m_fxSnow;

		StormGust(UnitPtr unit, SValue& params)
		{
			super(unit, params);
		
			m_duration = GetParamInt(unit, params, "duration");
			@m_unitProd = Resources::GetUnitProducer(GetParamString(unit, params, "unit", false));
			m_safeSpawning = GetParamBool(unit, params, "safe-spawn", false);

			m_spawnFx = GetParamString(unit, params, "spawn-fx", false);
			m_fxSnow = GetParamString(unit, params, "fx-snow", false);
			
			m_needNetSync = !IsNetsyncedExistance(m_unitProd.GetNetSyncMode());

			m_numUnits = GetParamInt(unit, params, "num-units");
		}
		
		TargetingMode GetTargetingMode(int &out size) override
		{
			size = 0;
			return TargetingMode::Direction;
		}
		
		void DoActivate(SValueBuilder@ builder, vec2 target) override
		{
			StartSpawning(false);
		}

		void NetDoActivate(SValue@ param, vec2 target) override
		{
			StartSpawning(true);
		}

		void StartSpawning(bool husk)
		{
			if (m_durationC > 0)
				return;

			m_spawningHusk = husk;
			m_durationC = m_duration - 1000;
			effectsSpawned = 0;
			auto cursor = cast<Skills::HeavensDrive>(cast<PlayerBase>(m_owner).m_skills[0]);
			m_spawnPos = xy(cursor.m_calcMousePos);
			LocalSpawnUnit(m_spawnPos, m_owner, 1.0f, m_spawningHusk);
			PlaySkillEffect(vec2());
		}

		float GetMoveSpeedMul() override { return m_durationC <= 0 ? 1.0 : m_speedMul; }

		void DoUpdate(int dt) override
		{
			if (m_durationC <= 0)
				return;

			m_durationC -= dt;
			for (uint i = 0; (i < max(1, m_numUnits / ((m_duration - 1000) / dt))) && effectsSpawned < m_numUnits; i++) {

				if (m_durationC >= 0 && (m_needNetSync || Network::IsServer()))
				{
					auto cursor = cast<Skills::HeavensDrive>(cast<PlayerBase>(m_owner).m_skills[0]);
					vec2 pos = m_spawnPos + makeRandomPos();

					float dir;
					int num = randi(2);
					if (num == 1) {
						dir = randf();
					} else {
						dir = -1 * randf();
					}
					float angle = min(0.4, dir);
					dictionary eps = {
						{ "fall_angle", angle}
					};
					PlayEffect(m_fxSnow, pos, eps);
					if (!m_needNetSync)
						(Network::Message("PlayEffectEPS") << HashString(m_fxSnow) << pos << angle).SendToAll();
					effectsSpawned++;
				}
			}
		}

		vec2 makeRandomPos() {
			int num = randi(4);
			if (num == 3) {
				return vec2(randi(5), randi(5));
			} else if (num == 2) {
				return vec2(-1 * randi(5), randi(5));
			} else if (num == 1) {
				return vec2(randi(5), -1 * randi(5));
			} else {
				return vec2(-1 * randi(5), -1 * randi(5));
			}
		}

		UnitPtr LocalSpawnUnit(vec2 pos, Actor@ owner, float intensity, bool husk, int id = 0)
		{
			auto unit = m_unitProd.Produce(g_scene, xyz(pos), id);

			if (!m_needNetSync)
				(Network::Message("PlayEffect") << HashString(m_spawnFx) << pos).SendToAll();

			if (owner !is null)
			{
				auto ownedUnit = cast<IOwnedUnit>(unit.GetScriptBehavior());
				if (ownedUnit !is null)
				{
					ownedUnit.Initialize(owner, intensity, husk, m_skillId + 1);

					if (!m_needNetSync && Network::IsServer())
						(Network::Message("SetOwnedUnit") << unit << owner.m_unit << intensity).SendToAll();
				}
			}

			return unit;
		}
	}
}