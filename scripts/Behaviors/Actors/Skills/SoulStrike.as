namespace Skills {

	class SoulStrike : Skill {

		int num_projectiles;
		UnitProducer@ m_projectile;
		int m_range;
		int m_minimumTargets;

		float shot_interval_orig;
		float shot_interval_temp;

        float m_betweenShotInterval;
        float m_betweenShotIntervalC;

		vec2 m_ownerPos;

		array<UnitPtr> m_targets;

        int m_shots;
        bool m_shooting = false;

		SoulStrike(UnitPtr unit, SValue& params)
		{
			super(unit);

			num_projectiles = GetParamInt(unit, params, "num-projectiles");
            @m_projectile = Resources::GetUnitProducer(GetParamString(unit, params, "projectile"));

            m_range = GetParamInt(unit, params, "range");
            m_minimumTargets = GetParamInt(unit, params, "min-targets");

            shot_interval_orig = GetParamFloat(unit, params, "interval", false, 5000.0f);
            shot_interval_temp = shot_interval_orig;

            m_betweenShotInterval = GetParamFloat(unit, params, "between-shots", false, 100.0f);
            m_betweenShotIntervalC = m_betweenShotInterval;
		}

		void Update(int dt, bool walking) override
		{
            if (m_shooting) {
                m_betweenShotIntervalC -= dt;
                if (m_betweenShotIntervalC < 0)  {
                    m_shots++;
                    m_betweenShotIntervalC = m_betweenShotInterval;

                    ShootProjectile(m_shots-1); 

                    if (m_shots == m_targets.length()) {
                        m_targets.removeRange(0, m_targets.length()); 
                        m_shooting = false;
                        m_shots = 0;
                    }
                    return;
                }
                return;
            }

			shot_interval_temp -= dt;
			if (shot_interval_temp < 0) {
				findTargets();
				if (m_targets.length() >= m_minimumTargets) {
					shot_interval_temp = shot_interval_orig;

                    m_shooting = true;
				}
			}
		}

		UnitPtr ProduceProjectile(vec2 m_shootPos, int id = 0)
		{
			return m_projectile.Produce(g_scene, xyz(m_shootPos), id);
		}

		vec2 GetTargetPosition(int index)
		{
			return xy(m_targets[index].GetPosition());
		}

        void findTargets() {
			m_ownerPos = xy(m_owner.m_unit.GetPosition());

            array<UnitPtr>@ results = g_scene.FetchActorsWithOtherTeam(m_owner.Team, m_ownerPos, m_range);
            for (uint i = 0; i < results.length(); i++)
            {
                Actor@ actor = cast<Actor>(results[i].GetScriptBehavior());
                if (!actor.IsTargetable())
                    continue;

                bool canSee = true;
                auto canSeeRes = g_scene.Raycast(m_ownerPos, xy(results[i].GetPosition()), ~0, RaycastType::Shot);
                for (uint j = 0; j < canSeeRes.length(); j++)
                {
                    UnitPtr canSeeUnit = canSeeRes[j].FetchUnit(g_scene);
                    if (canSeeUnit == results[i])
                        break;

                    auto canSeeActor = cast<Actor>(canSeeUnit.GetScriptBehavior());
                    if (canSeeActor is m_owner)
                        continue;

                    canSee = false;
                    break;
                }
                if (!canSee)
                    continue;

                bool found = false;
                for (uint j = 0; j < results.length(); j++) {
                	for (uint k = 0; k < m_targets.length(); k++) {
                		if (m_targets[k] == results[i]) {
	                		found = true;
	                		break;
	                	}
                	}
                	if (found == true) {
                		break;
                	}
                }
                if (!found)
                	m_targets.insertLast(results[i]);
            }
        }

		void ShootProjectile(int i) {
    		vec2 targetPos = GetTargetPosition(i);
			vec2 targetDirection = normalize(targetPos - xy(m_owner.m_unit.GetPosition()));

			auto proj = ProduceProjectile(xy(m_owner.m_unit.GetPosition()));
            if (!proj.IsValid())
                return;

            auto p = cast<SoulStrikeProjectile>(proj.GetScriptBehavior());
            if (p is null)
                return;

            p.Initialize(m_owner, findProjectileDirection(i+1), 1.0f, false, m_targets[i], 0);
            p.setTarget(m_targets[i]);

            auto pp = cast<Projectile>(p);
            if (pp !is null)
                pp.m_liveRangeSq *= m_range;   
		}

		vec2 findProjectileDirection(int num) {
			auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
			float dir = (player.m_dirAngle) / (m_targets.length() / num);
			return vec2(cos(dir), sin(dir)) * -10;
		}
	}
}