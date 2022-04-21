part of 'postgrest_builder.dart';

class PostgrestRpcBuilder extends PostgrestBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
  }) : super(
          url: Uri.parse(url),
          headers: headers ?? {},
          schema: schema,
          httpClient: httpClient,
        );

  /// Performs stored procedures on the database.
  PostgrestFilterBuilder rpc([dynamic params]) {
    _method = 'POST';
    _body = params;
    return PostgrestFilterBuilder(this);
  }
}
