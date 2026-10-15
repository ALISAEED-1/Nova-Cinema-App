import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../models/catalog.dart';

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Loads the catalogue.
///
/// The original web app kept its title data inline in each HTML page. That
/// data has been consolidated into a single bundled JSON document, read through
/// this service so the rest of the app never touches the source directly and a
/// remote API can be swapped in later without UI changes.
class CatalogService {
  const CatalogService({this.bundle});

  final AssetBundle? bundle;

  Future<Catalog> load() async {
    final String raw;
    try {
      raw = await (bundle ?? rootBundle).loadString(AppConstants.catalogAsset);
    } catch (_) {
      throw const CatalogException('The catalogue could not be loaded.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const CatalogException('The catalogue data is malformed.');
    }
    if (decoded is! Map<String, dynamic> || decoded['movies'] is! List) {
      throw const CatalogException('The catalogue data is incomplete.');
    }

    try {
      final catalog = Catalog.fromJson(decoded);
      if (catalog.movies.isEmpty) {
        throw const CatalogException('The catalogue is empty.');
      }
      return catalog;
    } on CatalogException {
      rethrow;
    } catch (_) {
      throw const CatalogException('The catalogue contains invalid entries.');
    }
  }
}
