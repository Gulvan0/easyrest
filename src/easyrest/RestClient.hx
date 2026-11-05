package easyrest;

import http.HttpRequest;
import jsonmodel.JsonSerializable;
import jsonmodel.exceptions.UnserializationException;
import easyrest.exceptions.GetPayloadProvidedException;
import haxe.Timer;
import http.HttpMethod;
import http.HttpError;
import http.HttpClient;
import http.StandardHeaders;
import http.ContentTypes;

using morestd.extensions.MapExtension;
using morestd.extensions.StringExtension;

/** Receives a response's headers (null if none arrived) and the local Unix times, in ms, the request was sent and the response received **/
typedef ResponseObserver = (headers:Null<Map<String, Any>>, sentAtMs:Float, receivedAtMs:Float)->Void;

private typedef RestOpInterface<Resp> = {
	final path:String;
	final method:HttpMethod;
	function deserializeResponse(bodyStr:String):Resp;
}

class RestClient
{
	private var baseUrl:String;
	private var httpClient:HttpClient = new HttpClient();
	private var commonHeaderRetrievers:Array<()->Map<String, String>> = [];
	private var responseObservers:Array<ResponseObserver> = [];

	/** Called with a description and the exception when a response can't be deserialized, whatever the caller makes of its `onHttpError` **/
	public var onDeserializationFailed:Null<String->Dynamic->Void> = null;

	/**
		How long a request may stay unanswered, in ms, before it fails through `onHttpError` with an `HttpError` that has no status.
		Whatever arrives afterwards is ignored, but the underlying request is not aborted. Null means no timeout.
	**/
	public var timeoutMs:Null<Int> = null;

	private function getHeaders(explicitHeaders:Null<Map<String, String>> = null):Map<String, String>
	{
		var headers:Map<String, String> = [];
		for (retriever in commonHeaderRetrievers)
			headers = headers.mergeWith(retriever());
		if (explicitHeaders != null)
			headers = headers.mergeWith(explicitHeaders);
		return headers;
	}

	public function execute<RequestPayloadType:JsonSerializable, ResponsePayloadType>(
		operation:RestOpInterface<ResponsePayloadType>,
		onResponse:ResponsePayloadType->Void,
		onHttpError:HttpError->Void = null,
		pathParams:Map<String, String> = null,
		queryParams:Map<String, Any> = null,
		body:RequestPayloadType = null,
		headers:Map<String, String> = null
	)
	{
		if (operation.method == HttpMethod.Get && body != null)
			throw new GetPayloadProvidedException();

		var url:String = baseUrl + operation.path.pythonicFormat(encodePathParams(pathParams ?? []));
		var serializedRequestPayload:String = body != null ? body.serialize() : null;

		var request:HttpRequest = new HttpRequest(url);
		request.method = operation.method;

		var finalHeaders:Map<String, String> = getHeaders(headers);
		if (serializedRequestPayload != null && !finalHeaders.exists(StandardHeaders.ContentType))
			finalHeaders.set(StandardHeaders.ContentType, ContentTypes.ApplicationJson);

		var sentAtMs:Float = std.Date.now().getTime();
		var settled:Bool = false;
		var timeoutTimer:Null<Timer> = null;
		var claimOutcome:()->Bool = () -> {
			if (settled)
				return false;

			settled = true;
			if (timeoutTimer != null)
				timeoutTimer.stop();
			return true;
		};

		if (timeoutMs != null)
		{
			var requestTimeoutMs:Int = timeoutMs;
			timeoutTimer = Timer.delay(() -> {
				if (claimOutcome() && onHttpError != null)
					onHttpError(new HttpError('No response within $requestTimeoutMs ms'));
			}, requestTimeoutMs);
		}

		httpClient.makeRequest(request, serializedRequestPayload, queryParams, finalHeaders).then(
			response -> {
				if (!claimOutcome())
					return;

				notifyResponseObservers(response.headers, sentAtMs);
				var parsedResponse:ResponsePayloadType;
				try
				{
					parsedResponse = operation.deserializeResponse(response.bodyAsString);
				}
				catch (exception:UnserializationException)
				{
					trace(exception);
					if (onDeserializationFailed != null)
						onDeserializationFailed('Failed to deserialize the response of ${operation.method} ${operation.path}', exception);
					if (onHttpError != null)
					{
						var deserializationError:HttpError = new HttpError("Failed to deserialize response", response.httpStatus);
						deserializationError.body = response.body;
						deserializationError.headers = response.headers;
						onHttpError(deserializationError);
					}
					return;
				}
				onResponse(parsedResponse);
			},
			error -> {
				if (!claimOutcome())
					return;

				notifyResponseObservers(error.headers, sentAtMs);
				if (onHttpError != null)
					onHttpError(error);
			}
		);
	}

	private function encodePathParams(pathParams:Map<String, String>):Map<String, String>
	{
		return [for (name => value in pathParams) name => StringTools.urlEncode(value)];
	}

	private function notifyResponseObservers(headers:Null<Map<String, Any>>, sentAtMs:Float)
	{
		var receivedAtMs:Float = std.Date.now().getTime();
		for (observer in responseObservers)
			observer(headers, sentAtMs, receivedAtMs);
	}

	public function addCommonHeaderRetriever(retriever:()->Map<String, String>)
	{
		commonHeaderRetrievers.push(retriever);
	}

	public function removeCommonHeaderRetriever(retriever:()->Map<String, String>)
	{
		commonHeaderRetrievers.remove(retriever);
	}

	/** Called on every response, error responses included **/
	public function addResponseObserver(observer:ResponseObserver)
	{
		responseObservers.push(observer);
	}

	public function removeResponseObserver(observer:ResponseObserver)
	{
		responseObservers.remove(observer);
	}

	public function new(baseUrl:String)
	{
		this.baseUrl = baseUrl;
	}
}
