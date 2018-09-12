library graphql_fetch.client;

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';
import 'package:meta/meta.dart';

part 'graphql_query.dart';

class RestClient extends http.BaseClient {
  http.Client _client;
  String _endpoint;
  Uri _baseUri;

  RestClient(this._endpoint) {
    this._client = new http.Client();
    this._baseUri = Uri.parse(this._endpoint);
  }

  void configureRequest(BaseRequest request) {}

  Future<StreamedResponse> send(BaseRequest request) {
    configureRequest(request);
    return _client.send(request);
  }

  String toJson(Map<String, dynamic> data) {
    return json.encode(data, toEncodable: toEncodable);
  }

  toEncodable(d) {
    for (ScalarSerializer c in scalarSerializers.values) {
      if (c.isType(d)) {
        return c.serialize(d);
      }
    }
    if (d is MapObject) {
      return d.toJson();
    }
    return d;
  }

  Future<JsonResponse> postJson(String path, Map<String, dynamic> data,
      {Map<String, String> headers}) async {
    String body = toJson(data);
    Uri uri = _baseUri.replace(path: _baseUri.path + path);
    Map<String, String> headersMap = {'Content-Type': 'application/json'};
    headersMap.addAll(headers);
    http.Response response =
          await this.post(uri.toString(), body: body, headers: headersMap).timeout(new Duration(seconds: 30));

    return handleJsonResponse(response);

  }

  JsonResponse handleJsonResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 400) {
      String bodyString = utf8.decode(response.bodyBytes);
      return new JsonResponse(bodyString);
    } else {
      throw new http.ClientException(
          "network error:${response.statusCode}\n" + response.body);
    }
  }

  Future<JsonResponse> putJson(String path, Map<String, dynamic> data) async {
    var body = toJson(data);
    Uri uri = _baseUri.replace(path: _baseUri.path + path);
    http.Response response = await this.put(uri.toString(),
        body: body, headers: {'Content-Type': 'application/json'});
    return handleJsonResponse(response);
  }

  Future<dynamic> getJson(String path, Map<String, dynamic> queries) async {
    Uri uri = _baseUri.replace(
        path: _baseUri.path + path, queryParameters: toQueries(queries));
    http.Response response = await this.get(uri.toString());
    return handleJsonResponse(response);
  }

  void close() {
    _client.close();
  }

  toQueries(Map<String, dynamic> queries) {
    return new Map.fromIterables(
        queries.keys, queries.values.map((v) => v.toString()));
  }
}

class GraphqlClient extends RestClient {
  GraphqlClient(String endpoint) : super(endpoint);

  Future<JsonResponse> request<T>(String query, Map<String, dynamic> variables,
      {String authToken}) async {
    Map<String, String> headersMap = {};
    if (authToken != null) {
      headersMap = {"Authorization": "Bearer $authToken"};
    }
    var result = await postJson("", {"query": query, "variables": variables},
        headers: headersMap);
    return result;
  }

  Future<GraphqlResponse<T>> query<T>(GraphqlQuery<T> query,
      {String authToken}) async {
    JsonResponse result =
        await request(query.query, query.variables, authToken: authToken);
    return result.decode((body) {
      Map map = json.decode(body);
      return new GraphqlResponse(query.constructorOfData, map);
    });
  }
}

main() async {
  String query = """
    query(\$alias: String) {
      allShows(filter: {
        aliases_some: {
          alias : \$alias
        }
      }){
        id
        title
        aliases {
          id
        }
      }
    }""";
  GraphqlClient cli = new GraphqlClient(
      "http://localhost:60000/simple/v1/cj9mldxkd008c017544mu2vhw");
  var result = await cli.request(query, {"alias": "atest"});
  print(result);
}
