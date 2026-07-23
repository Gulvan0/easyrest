package easyrest;

import http.HttpMethod;
import jsonmodel.JsonUnserializable;

@:generic
class GetOperaton<ResponsePayloadType:JsonUnserializable> extends GenericRestOperation<NoPayload, ResponsePayloadType>
{
	public function new(path:String)
	{
		super(path, Get);
	}
}
