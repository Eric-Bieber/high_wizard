namespace UnitHandler
{
	void PlayEffectEPS(uint eHash, vec2 pos, float angle)
	{
		dictionary eps = {
			{ "fall_angle", angle}
		};
		::PlayEffect(Resources::GetEffect(eHash), pos, eps);
	}
}