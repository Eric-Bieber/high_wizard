namespace Skills {

	class AmplifyMagic : Skill {

		float m_multiplier;
		float m_chargeTime;
		float m_chargeTimeC;

		bool chargeAvailable = false;

		string m_fx;
		UnitPtr m_fxUnit;
		EffectBehavior@ m_fxBehavior;

		int m_count = 0;

		ActorBuffDef@ m_buff;

		SoundEvent@ m_snd;
		SoundInstance@ m_soundI;

		AmplifyMagic(UnitPtr unit, SValue& params) {
			super(unit);

			m_multiplier = GetParamFloat(unit, params, "multiplier", false, 1.0f);

			m_chargeTime = GetParamFloat(unit, params, "charge-time", false, 1000.0f);
			m_chargeTimeC = m_chargeTime;

			m_fx = GetParamString(unit, params, "fx", false, "");

			@m_buff = LoadActorBuff(GetParamString(unit, params, "buff", true));

			@m_snd = Resources::GetSoundEvent(GetParamString(unit, params, "snd", false));
		}

		void Update(int dt, bool walking) override 
		{
			if (m_fxUnit.IsValid()) {
				auto input = GetInput();

				m_fxUnit.SetPosition(m_owner.m_unit.GetPosition() + vec3(-1,0,0) * input.MoveDir.x + vec3(0,-1,0) * input.MoveDir.y);
			}

			if (m_soundI !is null) {
				vec3 uPos = m_owner.m_unit.GetPosition();
				int mod = 0;
				if (uPos.y >= 0) {
					mod = -40;
				} else {
					mod = +40;
				}

				m_soundI.SetPosition(vec3(uPos.x, uPos.y+mod, uPos.z));
			}

			if (chargeAvailable) {
				return;
			}

			auto player = cast<Player>(m_owner.m_unit.GetScriptBehavior());
			if (player is null) {
				return;
			}

			vec2 playerMovement = m_owner.m_unit.GetMoveDir();
			if (playerMovement.x == 0 && playerMovement.y == 0) {
				m_chargeTimeC -= dt;
			} else {
				m_chargeTimeC = m_chargeTime;
			}

			if (m_chargeTimeC < 0) {
				chargeAvailable = true;
				m_chargeTimeC = m_chargeTime;

				if (m_fxUnit.IsValid()) {
					m_fxUnit.Destroy();
				}
				@m_soundI = m_snd.PlayTracked(m_owner.m_unit.GetPosition());
				m_fxUnit = PlayEffect(m_fx, m_owner.m_unit.GetPosition());
				(Network::Message("AttachEffect") << HashString(m_fx) << m_owner.m_unit).SendToAll();
				@m_fxBehavior = cast<EffectBehavior>(m_fxUnit.GetScriptBehavior());

				auto actor = cast<Actor>(m_owner.m_unit.GetScriptBehavior());
				auto behavior = cast<CompositeActorBehavior>(actor);
				actor.ApplyBuff(ActorBuff(behavior, m_buff, 1.0f, false));
			}
		}

		float GetChargeValue(bool isFirewall) {
			if (chargeAvailable) {
				if (isFirewall) {
					m_count++;

					auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());
					auto firewall = cast<Skills::Firewall>(player.m_skills[1]);

					if (m_count == firewall.m_width) {
						chargeAvailable = false;
						m_count = 0;
						removeBuff();
					}

					return m_multiplier;
				} else {
					chargeAvailable = false;
					removeBuff();
					return m_multiplier;
				}
			}
			return 1;
		}

		void removeBuff() {
			auto player = cast<PlayerBase>(m_owner.m_unit.GetScriptBehavior());

			if (player is null) {
				return;
			}

			for (uint j = 0; j < player.m_buffs.m_buffs.length(); j++) {
				if(player.m_buffs.m_buffs[j].m_def.m_name == "amplify-hud") {
					player.m_buffs.Remove(player.m_buffs.m_buffs[j].m_def.m_pathHash);
				}
			}
		}
	}
}