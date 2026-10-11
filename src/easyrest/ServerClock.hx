package easyrest;

/**
	Estimates the server's clock from a response header holding the server's Unix time in
	milliseconds. Feed it responses with `RestClient.addResponseObserver(clock.observe)`.
**/
class ServerClock
{
	// a sample is trusted at most this long, so a changed local clock gets picked up
	private static inline final SAMPLE_LIFETIME_MS:Float = 10 * 60 * 1000;

	private final headerName:String;
	private var offsetMs:Float = 0;
	private var sampleRoundTripMs:Null<Float> = null;
	private var sampleTakenAtMs:Float = 0;

	public function new(headerName:String)
	{
		this.headerName = headerName.toLowerCase();
	}

	/** Takes a response's sample if its round trip beats the current one or the current one is stale **/
	public function observe(headers:Null<Map<String, Any>>, sentAtMs:Float, receivedAtMs:Float)
	{
		var serverMs:Null<Float> = readServerMs(headers);
		if (serverMs == null)
			return;

		var roundTripMs:Float = receivedAtMs - sentAtMs;
		var stale:Bool = receivedAtMs - sampleTakenAtMs > SAMPLE_LIFETIME_MS;
		if (sampleRoundTripMs != null && roundTripMs > sampleRoundTripMs && !stale)
			return;

		offsetMs = serverMs - (sentAtMs + receivedAtMs) / 2;
		sampleRoundTripMs = roundTripMs;
		sampleTakenAtMs = receivedAtMs;
	}

	/** Whether any response carried the header yet; until then, the local clock is used **/
	public function isSynced():Bool
	{
		return sampleRoundTripMs != null;
	}

	/** How far the server's clock is ahead of the local one, in ms **/
	public function getOffsetMs():Float
	{
		return offsetMs;
	}

	/** The estimated server Unix time, in ms **/
	public function now():Float
	{
		return Date.now().getTime() + offsetMs;
	}

	private function readServerMs(headers:Null<Map<String, Any>>):Null<Float>
	{
		if (headers == null)
			return null;

		for (key => value in headers)
			if (key.toLowerCase() == headerName && value != null)
			{
				var parsed:Float = Std.parseFloat(StringTools.trim(Std.string(value)));
				return Math.isNaN(parsed) ? null : parsed;
			}

		return null;
	}
}
