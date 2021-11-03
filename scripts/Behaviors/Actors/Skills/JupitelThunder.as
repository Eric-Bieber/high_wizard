namespace Skills
{
	class JupitelThunder : ActiveSkill
	{
		array<IEffect@>@ m_effects;

		int m_dist;
		float m_distMul;
		int m_rays;
		float m_angleDelta;
		float m_angleOffset;
		int m_interval;
		bool m_husk;
		int m_swings;
		bool m_destroyProjectiles;

		int m_raysC;
		int m_intervalC;
		int m_swingsC;
		float m_angle;
		float m_angleStart;
		array<UnitPtr> m_arrHit;

		string m_hitFx;
		SoundEvent@ m_hitSnd;
		
		UnitScene@ m_fxBlockProjectile;

		bool m_fxStart;
		int m_fxCount;
		int m_fxCountC;

		int distance = 5;

		array<UnitPtr> m_hits;
		array<UnitPtr> canPush;

		vec2 m_dirHit;

		ActorBuffDef@ m_buff;

		int repeat = 0;

		vec2 start_dir;

		float m_multiplier = 1;

		JupitelThunder(UnitPtr unit, SValue& params)
		{
			super(unit, params);
		
			@m_effects = LoadEffects(unit, params);
			
			m_dist = GetParamInt(unit, params, "dist", false, 10);
			m_distMul = 1.0f;
			m_rays = GetParamInt(unit, params, "rays", false, 4);

			int arc = GetParamInt(unit, params, "arc", false, 45);
			m_angleDelta = (arc * PI / 180) / max(1, m_rays - 1);
			m_angleOffset = GetParamInt(unit, params, "angleoffset", false, -arc / 2) * PI / 180.f;
			m_swings = GetParamInt(unit, params, "swings", false, 1);
			m_interval = GetParamInt(unit, params, "duration", false, 150) / m_rays / m_swings - 1;
			
			m_hitFx = GetParamString(unit, params, "hit-fx", false);
			@m_hitSnd = Resources::GetSoundEvent(GetParamString(unit, params, "hit-snd", false));
			
			m_destroyProjectiles = GetParamBool(unit, params, "destroy-projectiles", false, false);
			@m_fxBlockProjectile = Resources::GetEffect("effects/players/block_projectile.effect");

			m_fxStart = GetParamBool(unit, params, "play-fx-start", false, true);
			m_fxCount = GetParamInt(unit, params, "play-fx-count", false, -1);

			@m_buff = LoadActorBuff(GetParamString(unit, params, "buff", true));
		}
		
		void Initialize(Actor@ owner, ScriptSprite@ icon, uint id) override
		{
			ActiveSkill::Initialize(owner, icon, id);
			PropagateWeaponInformation(m_effects, id + 1);
		}
		
		TargetingMode GetTargetingMode(int &out size) override
		{
			size = 0;
			return TargetingMode::Direction;
		}
		
		void DoActivate(SValueBuilder@ builder, vec2 target) override
		{
			StartSwing(target, false);
		}

		void NetDoActivate(SValue@ param, vec2 target) override
		{
			StartSwing(target, true);
		}

		void StartSwing(vec2 dir, bool husk)
		{
			if (m_raysC <= 0)
			{
				m_raysC = m_rays;
				m_swingsC = m_swings;
				m_intervalC = 0;
				m_angleStart = atan(dir.y, dir.x) + m_angleOffset;
				m_angle = m_angleStart + randf() * m_angleDelta;
				//m_arrHit.removeRange(0, m_arrHit.length());
				m_husk = husk;
				m_fxCountC = m_fxCount;
				start_dir = dir;
				
				if (m_fxStart) {
					auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
					PlaySkillEffect(dir, { { "angle", atan(dir.y, dir.x) } });
				}
			}
		}

		void DoUpdate(int dt) override
		{
			if (canPush.length() > 0) {

				for (uint i = 0; i < canPush.length(); i++) {
					auto input = GetInput();

					vec2 fromLocation = xy(canPush[i].GetPosition());
					vec2 toLocation = fromLocation + m_dirHit * distance;
					
					auto results = g_scene.Raycast(fromLocation, toLocation, ~0, RaycastType::Any);
					if (results.length() > 0)
					{	
						RaycastResult res = results[0];
							
						toLocation = res.point;
					}

					canPush[i].SetPosition(xyz(toLocation));
					m_hits[i].SetPosition(canPush[i].GetPosition());
				}
				
				repeat++;
			}

			if (repeat > 15) {
				canPush.removeRange(0, canPush.length());
				m_hits.removeRange(0, m_hits.length());
				repeat = 0;
			}

			if (m_raysC <= 0)
				return;

			m_intervalC -= dt;
			while (m_intervalC <= 0)
			{
				m_intervalC += m_interval;	
				

				bool hitSomething = false;

				vec2 ownerPos = xy(m_owner.m_unit.GetPosition()) + vec2(0, -Tweak::PlayerCameraHeight);
				vec2 rayDir = vec2(cos(m_angle), sin(m_angle));
				vec2 rayPos = ownerPos + rayDir * int(m_dist * m_distMul);
				array<RaycastResult>@ rayResults;
				
				if (m_rays > 1 && m_angleDelta == 0)
				{
					@rayResults = g_scene.RaycastWide(m_rays, m_rays, ownerPos, rayPos, ~0, m_destroyProjectiles ? RaycastType::Any : RaycastType::Shot);
					m_raysC = 0;
				}
				else
					@rayResults = g_scene.Raycast(ownerPos, rayPos, ~0, m_destroyProjectiles ? RaycastType::Any : RaycastType::Shot);
				
				vec2 endPoint = rayPos;

				for (uint i = 0; i < rayResults.length(); i++)
				{
					UnitPtr unit = rayResults[i].FetchUnit(g_scene);
					if (!unit.IsValid())
						continue;

					if (unit == m_owner.m_unit)
						continue;

					auto dmgTaker = cast<IDamageTaker>(unit.GetScriptBehavior());
					if (dmgTaker !is null && dmgTaker.ShootThrough(m_owner, rayPos, rayDir))
						continue;

					auto proj = cast<IProjectile>(unit.GetScriptBehavior());
					if (proj is null)
					{
						if (m_destroyProjectiles && !rayResults[i].fixture.RaycastTypeTest(RaycastType::Shot))
							continue;

						if (dmgTaker is null)// || dmgTaker.Impenetrable())
						{
							endPoint = rayResults[i].point;
							break;
						}
					}

					bool alreadyHit = false;
					for (uint j = 0; j < m_arrHit.length(); j++)
					{
						if (m_arrHit[j] == unit)
						{
							alreadyHit = true;
							break;
						}
					}
					if (alreadyHit)
						continue;

					m_arrHit.insertLast(unit);

					vec2 upos = xy(unit.GetPosition());
					
					if (proj !is null)
					{
						if (m_destroyProjectiles && proj.IsBlockable() && proj.Team != m_owner.Team)
						{
							PlayEffect(m_fxBlockProjectile, upos);
							unit.Destroy();
						}
						continue;
					}
					
					vec2 dir = normalize(xy(m_owner.m_unit.GetPosition()) - upos);					

					ApplyEffects(m_effects, m_owner, unit, upos, dir, 1.0, m_husk, 0, 0); // self/team/enemy dmg
					
					auto actor = cast<Actor>(unit.GetScriptBehavior());
					auto behavior = cast<CompositeActorBehavior>(actor);

					auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
					auto amp = cast<Skills::AmplifyMagic>(player.m_skills[6]);

					if (amp !is null) {
						m_multiplier *= amp.m_multiplier;
					}

					bool frozen = false;
					for (uint j = 0; j < behavior.m_buffs.m_buffs.length(); j++) {
						if(behavior.m_buffs.m_buffs[j].m_def.m_name == "stormgust-freeze") {
							actor.ApplyBuff(ActorBuff(behavior, m_buff, 2.0f * m_multiplier, false));
							frozen = true;
						}
					}
					if (!frozen) {
						actor.ApplyBuff(ActorBuff(behavior, m_buff, 1.0f * m_multiplier, false));
					}

					if (behavior.m_target !is null && behavior.m_enemyType != "construct" && !behavior.m_hasBossBar &&
						Reflect::GetTypeName(behavior.m_movement) != "PassiveMovement") { 
						canPush.insertLast(unit);

						auto input = GetInput();
						m_dirHit = input.AimDir;
					}

					dictionary ePs = { { 'angle', m_angle } };
					UnitPtr m_hit = PlayEffect(m_hitFx, rayResults[i].point, null);
					m_hits.insertLast(m_hit);

					if (dmgTaker !is null)
						hitSomething = true;
				}

				if (hitSomething)
					PlaySound3D(m_hitSnd, m_owner.m_unit.GetPosition());
				
				if (--m_raysC <= 0)
				{					
					m_arrHit.removeRange(0, m_arrHit.length());

					if (--m_swingsC > 0)
					{
						m_raysC = m_rays;
						m_intervalC = 0;
						m_angle = m_angleStart + randf() * m_angleDelta;

						PlaySkillEffect(vec2(cos(m_angle - m_angleOffset), sin(m_angle - m_angleOffset)), { { "angle", atan(start_dir.y, start_dir.x) } });
					}
					else if (--m_fxCountC >= 0) {
						PlaySkillEffect(vec2(cos(m_angle - m_angleOffset), sin(m_angle - m_angleOffset)), { { "angle", atan(start_dir.y, start_dir.x) } });
					}
					
					return;
				}
				
				m_angle += m_angleDelta;
			}
		}
	}
}