namespace Skills {
	class Firewall : ActiveSkill {
		
		string m_cursorFx;

		UnitPtr m_cursorFx_unit;
		EffectBehavior@ m_cursorFxBehavior;

		bool cursorActive = false;

		UnitProducer@ m_prod;
		bool m_needNetSync;

		uint m_maxCount;
		bool m_removeOldest;

		float m_distance;

        vec2 m_target;
        vec3 m_unitPos;

        float m_maxRange;

        int m_width;

		array<UnitPtr> m_units;

		vec3 m_currentMousePos;

		bool m_insideRange;

		vec3 m_maxCastPosition;

		Firewall(UnitPtr unit, SValue& params) {
			super(unit, params);

			m_cursorFx = GetParamString(unit, params, "cursor-fx", false, "");

			@m_prod = Resources::GetUnitProducer(GetParamString(unit, params, "unit"));
			m_needNetSync = !IsNetsyncedExistance(m_prod.GetNetSyncMode());

			m_maxCount = GetParamInt(unit, params, "max-count");
			m_width = GetParamInt(unit, params, "width");
			m_removeOldest = GetParamBool(unit, params, "remove-oldest", false);

			m_distance = GetParamFloat(unit, params, "offset", false, 0.0f);

			m_maxRange = GetParamFloat(unit, params, "max-range", false, 5.0f);
		}

		TargetingMode GetTargetingMode(int &out size) override { return TargetingMode::TargetAOE; }

		bool Activate(vec2 target) override
		{ 
			//Start ability stuff
			if (m_units.length() / m_width >= m_maxCount)
				return false;

			return ActiveSkill::Activate(target);
		}

		bool NeedNetParams() override { return true; }

		void spawnAtAngle(float dir, vec3 spawnPosition, vec2 target) {
			// S
			if (dir >= 1.18 && dir < 1.96) {
				spawnNS(spawnPosition, target);
			}

			// SW
			if (dir >= 1.96 && dir < 2.75) {
				spawnNESW(spawnPosition, target);
			}
			
			// W
			if (dir >= 2.75 || dir < -2.75) {
				spawnEW(spawnPosition, target);
			}

			// NW
			if (dir >= -2.75 && dir < -1.96) {
				spawnSENW(spawnPosition, target);
			}

			// N
			if (dir >= -1.96 && dir < -1.18) {
				spawnNS(spawnPosition, target);
			}

			// NE
			if (dir >= -1.18 && dir < -.38) {
				spawnNESW(spawnPosition, target);
			}

			// E
			if (dir >= -.38 && dir < .39) {
				spawnEW(spawnPosition, target);
			}

			// SE
			if (dir >= .39 && dir < 1.18) {
				spawnSENW(spawnPosition, target);
			}	
		}

		void spawnNS(vec3 spawnPosition, vec2 target) {
			if (m_width == 1) {
				SpawnUnit(spawnPosition, target);
			} else if (m_width == 3) {
				SpawnUnit(spawnPosition, target);
				SpawnUnit(spawnPosition + vec3(13,0,0), target);
            	SpawnUnit(spawnPosition + vec3(-13,0,0), target);
			} else if (m_width == 5) {
				SpawnUnit(spawnPosition, target);
				SpawnUnit(spawnPosition + vec3(13,0,0), target);
				SpawnUnit(spawnPosition + vec3(26,0,0), target);
            	SpawnUnit(spawnPosition + vec3(-13,0,0), target);
            	SpawnUnit(spawnPosition + vec3(-26,0,0), target);
			}
		}

		void spawnNESW(vec3 spawnPosition, vec2 target) {
			if (m_width == 1) {
				SpawnUnit(spawnPosition, target);
			} else if (m_width == 3) {
				SpawnUnit(spawnPosition, target);
	            SpawnUnit(spawnPosition + vec3(10,10,0), target);
	            SpawnUnit(spawnPosition + vec3(-10,-10,0), target);
			} else if (m_width == 5) {
				SpawnUnit(spawnPosition, target);
	            SpawnUnit(spawnPosition + vec3(10,10,0), target);
	            SpawnUnit(spawnPosition + vec3(20,20,0), target);
	            SpawnUnit(spawnPosition + vec3(-10,-10,0), target);
	            SpawnUnit(spawnPosition + vec3(-20,-20,0), target);
			}
		}

		void spawnEW(vec3 spawnPosition, vec2 target) {
			if (m_width == 1) {
				SpawnUnit(spawnPosition, target);
			} else if (m_width == 3) {
				SpawnUnit(spawnPosition, target);
	            SpawnUnit(spawnPosition + vec3(0,13,0), target);
	            SpawnUnit(spawnPosition + vec3(0,-13,0), target);
			} else if (m_width == 5) {
				SpawnUnit(spawnPosition, target);
	            SpawnUnit(spawnPosition + vec3(0,13,0), target);
	            SpawnUnit(spawnPosition + vec3(0,26,0), target);
	            SpawnUnit(spawnPosition + vec3(0,-13,0), target);
	            SpawnUnit(spawnPosition + vec3(0,-26,0), target);
			}
		}

		void spawnSENW(vec3 spawnPosition, vec2 target) {
			if (m_width == 1) {
				SpawnUnit(spawnPosition, target);
			} else if (m_width == 3) {
				SpawnUnit(spawnPosition, target);
                SpawnUnit(spawnPosition + vec3(-10,10,0), target);
                SpawnUnit(spawnPosition + vec3(10,-10,0), target);
			} else if (m_width == 5) {
				SpawnUnit(spawnPosition, target);
                SpawnUnit(spawnPosition + vec3(-10,10,0), target);
                SpawnUnit(spawnPosition + vec3(-20,20,0), target);
            	SpawnUnit(spawnPosition + vec3(10,-10,0), target);
            	SpawnUnit(spawnPosition + vec3(20,-20,0), target);
			}
		}

		void DoActivate(SValueBuilder@ builder, vec2 target) override
		{
			vec3 unitPos = m_owner.m_unit.GetPosition() + xyz(target * m_distance);
			unitPos.z = 0;
            m_unitPos = unitPos;
			builder.PushVector3(unitPos);

			float dir = atan(target.y, target.x);

			if (m_units.length() / m_width < m_maxCount) {
				if (m_insideRange) {
                	spawnAtAngle(dir, m_currentMousePos, target);
	            } else {
	            	spawnAtAngle(dir, m_maxCastPosition, target);
	            }
			} else {
				return;
			}
            
            PlaySkillEffect(target);
		}

		void NetDoActivate(SValue@ param, vec2 target) override
		{
			if (!m_needNetSync && !Network::IsServer())
			{
				PlaySkillEffect(target);
				return;
			}
            PlaySkillEffect(target);

			vec3 unitPos = param.GetVector3();
            m_unitPos = unitPos;
		}

		void DoUpdate(int dt) override
		{
			// Crosshair management
			if (!cursorActive) {
				StartCursorEffect();
			}

			m_currentMousePos = ToWorldspace(GetGameModeMousePosition());

			float distance = dist(xy(m_currentMousePos), xy(m_owner.m_unit.GetPosition()));
			if (distance > m_maxRange) {
				auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
				float dir = player.m_dirAngle;
				vec2 rayDir = vec2(cos(dir), sin(dir));

				m_maxCastPosition = m_owner.m_unit.GetPosition() + xyz(rayDir) * int(m_maxRange);
				m_cursorFx_unit.SetPosition(m_maxCastPosition);
				m_insideRange = false;
			} else {
				m_cursorFx_unit.SetPosition(m_currentMousePos);
				m_insideRange = true;
			}


			for (int i = m_units.length() - 1; i >= 0; i--)
			{
				if (m_units[i].IsDestroyed()) {
                    m_units.removeAt(i);
                }
			}
		}

		UnitPtr SpawnUnit(vec3 pos, vec2 target)
		{
			UnitPtr unit = m_prod.Produce(g_scene, pos);

			auto ownedUnit = cast<IOwnedUnit>(unit.GetScriptBehavior());
			if (ownedUnit !is null)
			{
				ownedUnit.Initialize(m_owner, 1.0f, false, m_skillId + 1);

				if (!m_needNetSync && Network::IsServer())
					(Network::Message("SetOwnedUnit") << unit << m_owner.m_unit << 1.0f).SendToAll();
			}

			m_units.insertLast(unit);

			if (m_removeOldest && m_units.length() / m_width > m_maxCount)
			{
				for (uint i = 0; i < m_width; i++) {
					UnitPtr unitToRemove = m_units[0];
					m_units.removeAt(0);
					unitToRemove.Destroy();
				}
			}

			return unit;
		}

		void StartCursorEffect()
		{
			auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
			float dir = player.m_dirAngle;
			vec2 aimDir = vec2(cos(dir), sin(dir));

			vec2 pos = (GetGameModeMousePosition() / g_gameMode.m_wndScale);

			m_cursorFx_unit = PlayEffect(m_cursorFx, pos);

			@m_cursorFxBehavior = cast<EffectBehavior>(m_cursorFx_unit.GetScriptBehavior());
			m_cursorFxBehavior.m_looping = true;

			cursorActive = true;
		}
	}
}