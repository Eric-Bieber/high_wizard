namespace Skills {
	class HeavensDrive : ActiveSkill {
		
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

		array<UnitPtr> m_units;

		vec3 m_currentMousePos;

		bool m_insideRange;

		vec3 m_maxCastPosition;

		vec3 m_calcMousePos;

		HeavensDrive(UnitPtr unit, SValue& params) {
			super(unit, params);

			m_cursorFx = GetParamString(unit, params, "cursor-fx", false, "");

			@m_prod = Resources::GetUnitProducer(GetParamString(unit, params, "unit"));
			m_needNetSync = !IsNetsyncedExistance(m_prod.GetNetSyncMode());

			m_maxCount = GetParamInt(unit, params, "max-count");
			m_removeOldest = GetParamBool(unit, params, "remove-oldest", false);

			m_distance = GetParamFloat(unit, params, "offset", false, 0.0f);

			m_maxRange = GetParamFloat(unit, params, "max-range", false, 5.0f);
		}

		TargetingMode GetTargetingMode(int &out size) override { return TargetingMode::TargetAOE; }

		bool Activate(vec2 target) override
		{ 
			if (!m_removeOldest && m_units.length() >= m_maxCount)
				return false;

			return ActiveSkill::Activate(target);
		}

		bool NeedNetParams() override { return true; }

		void DoActivate(SValueBuilder@ builder, vec2 target) override
		{
			vec3 unitPos = m_owner.m_unit.GetPosition() + xyz(target * m_distance);
			unitPos.z = 0;
            m_unitPos = unitPos;
			builder.PushVector3(unitPos);

            if (m_units.length() < m_maxCount) {
            	if (m_insideRange) {
                	SpawnUnit(m_currentMousePos, m_target);
	            } else {
	            	SpawnUnit(m_maxCastPosition, m_target);
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
			if (!cursorActive && Network::IsServer()) {
				StartCursorEffect();
			}

			m_currentMousePos = ToWorldspace(GetGameModeMousePosition());

			float distance = dist(xy(m_currentMousePos), xy(m_owner.m_unit.GetPosition()));
			if (distance > m_maxRange) {
				m_maxCastPosition = calcMaxPos();

				m_cursorFx_unit.SetPosition(m_maxCastPosition);
				m_calcMousePos = m_maxCastPosition;
				m_insideRange = false;
			} else {
				m_currentMousePos = checkWithinBounds(xy(m_currentMousePos));
				m_cursorFx_unit.SetPosition(m_currentMousePos);
				m_calcMousePos = m_currentMousePos;
				m_insideRange = true;
			}

			for (int i = m_units.length() - 1; i >= 0; i--)
			{
				if (m_units[i].IsDestroyed()) {
                    m_units.removeAt(i);
                }
			}
		}

		vec3 calcMaxPos() {
			auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
			float dir = player.m_dirAngle;
			vec2 rayDir = vec2(cos(dir), sin(dir));

			vec3 maxPos = m_owner.m_unit.GetPosition() + xyz(rayDir) * int(m_maxRange);
			return checkWithinBounds(xy(maxPos));
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

			if (m_removeOldest && m_units.length() > m_maxCount)
			{
				UnitPtr unitToRemove = m_units[0];
				m_units.removeAt(0);
				unitToRemove.Destroy();
			}

			return unit;
		}

		vec3 checkWithinBounds(vec2 toLocation) {
			vec2 fromLocation = xy(m_owner.m_unit.GetPosition());
			
			auto results = g_scene.Raycast(fromLocation, toLocation, ~0, RaycastType::Aim);
			if (results.length() > 0)
			{	
				RaycastResult res = results[0];

				toLocation = res.point;

				return xyz(toLocation);
			}
			return xyz(toLocation);
		}

		void StartCursorEffect()
		{
			vec2 pos = (GetGameModeMousePosition() / g_gameMode.m_wndScale);

			m_cursorFx_unit = PlayEffect(m_cursorFx, pos);

			@m_cursorFxBehavior = cast<EffectBehavior>(m_cursorFx_unit.GetScriptBehavior());
			m_cursorFxBehavior.m_looping = true;

			cursorActive = true;
		}
	}
}