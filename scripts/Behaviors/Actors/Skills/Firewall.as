namespace Skills {
	class Firewall : ActiveSkill {
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
		float m_cursorDir;

		AnimString@ one;
		AnimString@ three;
		AnimString@ five;

		bool m_cursorActive = false;

		bool canSpawn = false;

		Firewall(UnitPtr unit, SValue& params) {
			super(unit, params);

			@m_prod = Resources::GetUnitProducer(GetParamString(unit, params, "unit"));
			m_needNetSync = !IsNetsyncedExistance(m_prod.GetNetSyncMode());

			m_maxCount = GetParamInt(unit, params, "max-count");
			m_width = GetParamInt(unit, params, "width");
			m_removeOldest = GetParamBool(unit, params, "remove-oldest", false);

			m_distance = GetParamFloat(unit, params, "offset", false, 0.0f);

			m_maxRange = GetParamFloat(unit, params, "max-range", false, 5.0f);

			@one = AnimString(GetParamString(unit, params, "one"));
			@three = AnimString(GetParamString(unit, params, "three"));
			@five = AnimString(GetParamString(unit, params, "five"));
		}

		void RefreshScene(CustomUnitScene@ scene) override
		{
			if (m_cursorActive) {
				auto cursor = cast<Skills::HeavensDrive>(cast<PlayerBase>(m_owner).m_skills[0]);
				if (m_width == 1) {
					auto sceneTemp = GetCursorScene(one);
					vec2 calcPos = xy(cursor.m_calcMousePos) - xy(m_owner.m_unit.GetPosition());
					scene.AddScene(sceneTemp, 0, calcPos + vec2(2, 1), -1, 0);
				} else if (m_width == 3) {
					auto sceneTemp = GetCursorScene(three);
					vec2 calcPos = xy(cursor.m_calcMousePos) - xy(m_owner.m_unit.GetPosition());
					scene.AddScene(sceneTemp, 0, calcPos + vec2(2, 1), -1, 0);
				} else if (m_width == 5) {
					auto sceneTemp = GetCursorScene(five);
					vec2 calcPos = xy(cursor.m_calcMousePos) - xy(m_owner.m_unit.GetPosition());
					scene.AddScene(sceneTemp, 0, calcPos + vec2(2, 1), -1, 0);
				}
			}
		}

		UnitScene@ GetCursorScene(AnimString@ anim) {
			string sceneName = anim.GetSceneName(m_cursorDir); 
			auto prod = Resources::GetUnitProducer("players/highwizard/firewall_cursor.unit");
			return prod.GetUnitScene(sceneName);
		}

		TargetingMode GetTargetingMode(int &out size) override { return TargetingMode::Channeling; }

		bool Activate(vec2 target) override
		{ 
			//Start ability stuff
			if (m_units.length() / m_width >= m_maxCount)
				return false;

			int targetSz = 0;
			TargetingMode targetMode = GetTargetingMode(targetSz);

			if (m_cooldownC > 0)
			{
				m_owner.WarnCooldown(this, m_cooldownC);
				return false;
			}

			if (!m_owner.SpendCost(m_costMana, m_costStamina, m_costHealth))
				return false;
				
			if (m_skillId == 0)
				Tutorial::RegisterAction("attack1");
			else if (m_skillId == 1)
				Tutorial::RegisterAction("attack2");
		
			if (targetMode != TargetingMode::Toggle)
				m_cooldownC = m_cooldown;
			m_castingC = m_castpoint;

			PlaySound3D(m_soundStart, m_owner.m_unit.GetPosition());
			
			m_queuedTarget = target;
			m_animCountdown = m_owner.SetUnitScene(m_animation, true);

			(Network::Message("PlayerActiveSkillActivate") << int(m_skillId) << target).SendToAll();
			
			canSpawn = true;

			return true;

			//return ActiveSkill::Activate(target);
		}

		void Hold(int dt, vec2 target) override
		{
			if (!canSpawn) {
				return;
			}

			if (!m_cursorActive) {
				float dir = atan(target.y, target.x);
				auto cursor = cast<Skills::HeavensDrive>(cast<PlayerBase>(m_owner).m_skills[0]);
				cursor.m_cursorFx_unit.Destroy();
				
				m_cursorDir = dir;
				m_cursorActive = true;
			}
			float dir = atan(target.y, target.x);
			m_cursorDir = dir;
		}

		void Release(vec2 target) override
		{
			if (!canSpawn) {
				return;
			}

			m_cursorActive = false;
			auto cursor = cast<Skills::HeavensDrive>(cast<PlayerBase>(m_owner).m_skills[0]);
			cursor.StartCursorEffect();

			float dir = atan(target.y, target.x);
			if (m_units.length() / m_width < m_maxCount) {
				if (cursor.m_insideRange) {
                	spawnAtAngle(dir, cursor.m_calcMousePos, target);
	            } else {
	            	spawnAtAngle(dir, cursor.m_calcMousePos, target);
	            }
	            PlaySound3D(m_sound, xyz(target));
	            PlaySkillEffect(target);
			}
			canSpawn = false;
		}

		void NetRelease(vec2 target) override
		{
			if (!canSpawn) {
				return;
			}
			if (!m_needNetSync && !Network::IsServer())
			{
				PlaySkillEffect(target);
				return;
			}
	        PlaySkillEffect(target);
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

		void DoUpdate(int dt) override
		{
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
	}
}