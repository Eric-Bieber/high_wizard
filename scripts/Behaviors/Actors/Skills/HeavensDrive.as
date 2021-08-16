namespace Skills {
	class HeavensDrive : ActiveSkill {
		
		string m_cursorFx;

		UnitPtr m_cursorFx_unit;
		EffectBehavior@ m_cursorFxBehavior;

		bool cursorActive = false;

		HeavensDrive(UnitPtr unit, SValue& params) {
			super(unit, params);

			m_cursorFx = GetParamString(unit, params, "cursor-fx", false, "");
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

		bool Activate(vec2 target) override
		{ 
			//Start ability stuff
			print("BOOM");
			return false;
		}

		void Update(int dt, bool walking) override
		{
			// Crosshair management
			if (!cursorActive) {
				StartCursorEffect();
			}

			vec3 mousePos = ToWorldspace(GetGameModeMousePosition());

			m_cursorFx_unit.SetPosition(mousePos);

			ActiveSkill::Update(dt, walking);
		}
	}
}