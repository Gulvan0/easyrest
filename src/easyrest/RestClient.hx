package easyrest;

import http.HttpRequest;
import jsonmodel.JsonSerializable;
import jsonmodel.exceptions.UnserializationException;
import easyrest.exceptions.GetPayloadProvidedException;
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

		var url:String = baseUrl + operation.path.pythonicFormat(pathParams ?? []);
		var serializedRequestPayload:String = body != null ? body.serialize() : null;

		var request:HttpRequest = new HttpRequest(url);
		request.method = operation.method;

		var finalHeaders:Map<String, String> = getHeaders(headers);
		if (serializedRequestPayload != null && !finalHeaders.exists(StandardHeaders.ContentType))
			finalHeaders.set(StandardHeaders.ContentType, ContentTypes.ApplicationJson);

		var sentAtMs:Float = std.Date.now().getTime();
		httpClient.makeRequest(request, serializedRequestPayload, queryParams, finalHeaders).then(
			response -> {
				notifyResponseObservers(response.headers, sentAtMs);
				try
				{
					var parsedResponse:ResponsePayloadType = operation.deserializeResponse(response.bodyAsString);
					onResponse(parsedResponse);
				}
				catch (exception:UnserializationException)
				{
					trace(exception);
					if (onHttpError != null)
					{
						var deserializationError:HttpError = new HttpError("Failed to deserialize response", response.httpStatus);
						deserializationError.body = response.body;
						deserializationError.headers = response.headers;
						onHttpError(deserializationError);
					}
				}
			},
			error -> {
				notifyResponseObservers(error.headers, sentAtMs);
				if (onHttpError != null)
					onHttpError(error);
			}
		);
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
