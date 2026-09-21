import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/data/catalog/catalog_client.dart';

final _jpeg = <int>[0xFF, 0xD8, 0xFF, ...List<int>.filled(3000, 0)];

Dio _dio(
  Response? Function(RequestOptions) reply, {
  Duration Function(RequestOptions options)? delayFor,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final delay = delayFor?.call(options) ?? Duration.zero;
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        final res = reply(options);
        if (res == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          return;
        }
        final status = res.statusCode ?? 200;
        if (status < 200 || status >= 300) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: res,
            ),
          );
          return;
        }
        handler.resolve(res);
      },
    ),
  );
  return dio;
}

Response _json(
  RequestOptions options,
  Map<String, dynamic> data, {
  int status = 200,
}) => Response(requestOptions: options, statusCode: status, data: data);

Response _xml(RequestOptions options, String xml, {int status = 200}) =>
    Response(requestOptions: options, statusCode: status, data: xml);

Response _bytes(RequestOptions options, List<int> data) => Response(
  requestOptions: options,
  statusCode: 200,
  data: data,
);

Response? _catalogReply(
  RequestOptions options, {
  Map<String, dynamic>? openLibrary,
  String bneXml = '<records></records>',
  Map<String, dynamic>? wikidata,
}) {
  final host = options.uri.host;
  if (host.contains('query.wikidata.org')) {
    return _json(
      options,
      wikidata ??
          {
            'results': {'bindings': <Object>[]},
          },
    );
  }
  if (host.contains('datos.bne.es')) {
    return _json(options, {
      'results': {'bindings': <Object>[]},
    });
  }
  if (host.contains('covers.openlibrary') ||
      host.contains('casadellibro.com') ||
      host.contains('imagessl')) {
    return _bytes(options, _jpeg);
  }
  if (host.contains('empathy.co')) {
    return _json(options, {
      'catalog': {'content': <Object>[], 'numFound': 0},
    });
  }
  if (host.contains('openlibrary.org')) {
    return _json(options, openLibrary ?? const {});
  }
  if (host.contains('bne.es')) return _xml(options, bneXml);
  return _json(options, const {});
}

void main() {
  test('search merges Open Library and BNE by ISBN', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'numFound': 1,
            'docs': [
              {
                'title': 'Rayuela',
                'author_name': ['Cortázar'],
                'isbn': ['9788437604572'],
                'subject': ['Fiction'],
                'cover_i': 14407898,
              },
            ],
          },
          bneXml:
              '<records><dc:title>Rayuela</dc:title><dc:creator>Cortázar</dc:creator></records>',
        ),
      ),
    );
    final page = await client.search('Rayuela');
    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Rayuela');
    expect(page.items.first.isbn, '9788437604572');
    expect(page.items.first.categoryCodes, ['fiction']);
    expect(page.items.first.coverUrl, contains('openlibrary.org'));
  });

  test('ISBN lookup fills from Open Library then Wikidata blurb', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'title': 'Rayuela',
            'authors': [
              {'name': 'Cortázar'},
            ],
            'subjects': ['Fiction'],
            'covers': [99],
          },
          wikidata: {
            'results': {
              'bindings': [
                {
                  'desc': {'value': 'Novela de Julio Cortázar'},
                },
              ],
            },
          },
        ),
      ),
    );
    final hit = await client.lookupIsbn('9788437604572');
    expect(hit?.title, 'Rayuela');
    expect(hit?.categoryCodes, ['fiction']);
    expect(hit?.coverUrl, contains('openlibrary.org'));
    expect(hit?.description, 'Novela de Julio Cortázar');
  });

  test('ISBN lookup uses BNE when Open Library is empty', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          bneXml:
              '<record><dc:title>ISBN book</dc:title><dc:creator>Anon</dc:creator></record>',
        ),
      ),
    );
    final hit = await client.lookupIsbn('9788437604572');
    expect(hit?.title, 'ISBN book');
  });

  test('text search asks Open Library for Spanish', () async {
    String? language;
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.path.contains('search.json')) {
          language = options.uri.queryParameters['language'];
        }
        return _catalogReply(
          options,
          openLibrary: {
            'numFound': 1,
            'docs': [
              {
                'title': 'Rayuela',
                'author_name': ['Cortázar'],
                'isbn': ['9788437604572'],
                'language': ['spa'],
              },
            ],
          },
        );
      }),
    );
    await client.search('Rayuela');
    expect(language, 'spa');
  });

  test('ISBN lookup search.json is not restricted to Spanish', () async {
    String? language;
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.path.contains('search.json')) {
          language = options.uri.queryParameters['language'];
          return _json(options, {
            'numFound': 1,
            'docs': [
              {
                'title': 'Dune',
                'author_name': ['Herbert'],
                'isbn': ['9780441172719'],
                'language': ['eng'],
              },
            ],
          });
        }
        if (options.uri.path.contains('/isbn/')) {
          return _json(options, {
            'title': 'Dune',
            'authors': [
              {'key': '/authors/OL1A'},
            ],
          });
        }
        return _catalogReply(options);
      }),
    );
    final hit = await client.lookupIsbn('9780441172719');
    expect(hit?.title, 'Dune');
    expect(hit?.authors, ['Herbert']);
    expect(language, isNull);
  });

  test(
    'ISBN lookup still searches when isbn.json only has a by-statement',
    () async {
      var searchJson = 0;
      final client = CatalogClient(
        dio: _dio((options) {
          final path = options.uri.path;
          if (path.contains('search.json')) {
            searchJson++;
            return _json(options, {
              'numFound': 1,
              'docs': [
                {
                  'title': 'Rayuela',
                  'author_name': ['Julio Cortázar'],
                  'isbn': ['9788437604572'],
                },
              ],
            });
          }
          if (path.contains('/isbn/')) {
            return _json(options, {
              'title': 'Rayuela',
              'by_statement': 'Julio Cortázar',
            });
          }
          return _catalogReply(options);
        }),
      );
      final hit = await client.lookupIsbn('9788437604572');
      expect(searchJson, 1);
      expect(hit?.title, 'Rayuela');
      expect(hit?.authors, ['Julio Cortázar']);
    },
  );

  test(
    'ISBN lookup prefers BNE SRU title over SPARQL cover-only',
    () async {
      final client = CatalogClient(
        dio: _dio(
          (options) {
            if (options.uri.host.contains('datos.bne.es')) {
              return _json(options, {
                'results': {
                  'bindings': [
                    {
                      'img': {
                        'value':
                            'https://covers.openlibrary.org/b/id/1-L.jpg?default=false',
                      },
                    },
                  ],
                },
              });
            }
            return _catalogReply(
              options,
              bneXml:
                  '<record><dc:title>Título SRU</dc:title><dc:creator>Anon</dc:creator></record>',
            );
          },
          delayFor: (options) {
            if (options.uri.host.contains('catalogo.bne.es')) {
              return const Duration(milliseconds: 30);
            }
            return Duration.zero;
          },
        ),
      );
      final hit = await client.lookupIsbn('9788437604572');
      expect(hit?.title, 'Título SRU');
      expect(hit?.coverUrl, contains('covers.openlibrary.org'));
    },
  );

  test('ISBN lookup fills Open Library authors from search.json', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        final path = options.uri.path;
        if (path.contains('search.json')) {
          return _json(options, {
            'numFound': 1,
            'docs': [
              {
                'title': 'Rayuela',
                'author_name': ['Julio Cortázar'],
                'isbn': ['9788437604572'],
              },
            ],
          });
        }
        if (path.contains('/isbn/')) {
          return _json(options, {
            'title': 'Rayuela',
            'authors': [
              {'key': '/authors/OL123A'},
            ],
          });
        }
        return _catalogReply(options);
      }),
    );
    final hit = await client.lookupIsbn('9788437604572');
    expect(hit?.title, 'Rayuela');
    expect(hit?.authors, ['Julio Cortázar']);
  });

  test('enrich fills cover and categories from Open Library', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'title': 'Dune',
            'authors': [
              {'name': 'Frank Herbert'},
            ],
            'subjects': ['Science fiction'],
            'covers': [99],
          },
        ),
      ),
    );
    final hit = await client.enrich(
      isbn: '9780441172719',
      title: 'Dune',
      authors: const ['Frank Herbert'],
    );
    expect(hit?.title, 'Dune');
    expect(hit?.coverUrl, contains('openlibrary.org'));
    expect(hit?.categoryCodes, ['science_fiction']);
  });

  test('enrich does not take an unmatched Open Library first hit', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'numFound': 1,
            'docs': [
              {
                'title': 'Bestseller ajeno',
                'author_name': ['Otro'],
                'subject': ['Fiction'],
              },
            ],
          },
        ),
      ),
    );
    final hit = await client.enrich(
      title: 'Rayuela',
      authors: const ['Cortázar'],
    );
    expect(hit?.title, 'Rayuela');
    expect(hit?.authors, ['Cortázar']);
    expect(hit?.categoryCodes, isEmpty);
  });

  test('search connection errors rethrow when every source fails', () async {
    await expectLater(
      CatalogClient(dio: _dio((_) => null)).search('cualquier cosa'),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'ISBN lookup connection errors rethrow when every source fails',
    () async {
      await expectLater(
        CatalogClient(dio: _dio((_) => null)).lookupIsbn('9788437604572'),
        throwsA(isA<DioException>()),
      );
    },
  );

  test('search keeps Empathy when Open Library is down', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('openlibrary.org')) return null;
        if (options.uri.host.contains('empathy.co')) {
          return _json(options, {
            'catalog': {
              'numFound': 1,
              'content': [
                {
                  'name': 'Carl el Mazmorrero',
                  'authors': ['Matt Dinniman'],
                  'ean': '9788410466135',
                },
              ],
            },
          });
        }
        return _catalogReply(options);
      }),
    );
    final page = await client.search('Carl el mazmorrero');
    expect(page.items, isNotEmpty);
    expect(page.items.first.title, contains('Carl el Mazmorrero'));
    expect(page.items.first.isbn, '9788410466135');
  });

  test('search keeps Open Library when Empathy returns HTTP 500', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('empathy.co')) {
          return _json(options, {'error': 'boom'}, status: 500);
        }
        return _catalogReply(
          options,
          openLibrary: {
            'numFound': 1,
            'docs': [
              {
                'title': 'Rayuela',
                'author_name': ['Cortázar'],
                'isbn': ['9788437604572'],
                'language': ['spa'],
              },
            ],
          },
        );
      }),
    );
    final page = await client.search('Rayuela');
    expect(page.items, isNotEmpty);
    expect(page.items.first.title, 'Rayuela');
  });

  test('search keeps BNE when Open Library payload is malformed', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('openlibrary.org')) {
          return _json(options, {'docs': 'not-a-list'});
        }
        return _catalogReply(
          options,
          bneXml:
              '<record><dc:title>Libro BNE</dc:title><dc:creator>Anon</dc:creator></record>',
        );
      }),
    );
    final page = await client.search('Rayuela');
    expect(page.items.map((e) => e.title), contains('Libro BNE'));
  });

  test('ISBN lookup keeps Empathy when Open Library is down', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('openlibrary.org')) return null;
        if (options.uri.host.contains('empathy.co')) {
          return _json(options, {
            'catalog': {
              'numFound': 1,
              'content': [
                {
                  'name': 'Carl el Mazmorrero',
                  'authors': ['Matt Dinniman'],
                  'ean': '9788410466135',
                },
              ],
            },
          });
        }
        return _catalogReply(options);
      }),
    );
    final hit = await client.lookupIsbn('9788410466135');
    expect(hit?.title, 'Carl el Mazmorrero');
    expect(hit?.isbn, '9788410466135');
  });

  test(
    'ISBN lookup keeps Open Library when Empathy payload is malformed',
    () async {
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.host.contains('empathy.co')) {
            return _json(options, {'catalog': 'not-a-map'});
          }
          return _catalogReply(
            options,
            openLibrary: {
              'title': 'Rayuela',
              'authors': [
                {'name': 'Cortázar'},
              ],
              'covers': [99],
            },
          );
        }),
      );
      final hit = await client.lookupIsbn('9788437604572');
      expect(hit?.title, 'Rayuela');
      expect(hit?.authors, ['Cortázar']);
    },
  );

  test('ISBN lookup keeps Open Library when BNE times out', () async {
    final client = CatalogClient(
      secondaryTimeout: const Duration(milliseconds: 40),
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'title': 'Rayuela',
            'authors': [
              {'name': 'Cortázar'},
            ],
            'covers': [99],
          },
        ),
        delayFor: (options) {
          if (options.uri.host.contains('bne.es')) {
            return const Duration(milliseconds: 250);
          }
          return Duration.zero;
        },
      ),
    );
    final sw = Stopwatch()..start();
    final hit = await client.lookupIsbn('9788437604572');
    sw.stop();
    expect(hit?.title, 'Rayuela');
    expect(sw.elapsedMilliseconds, lessThan(200));
  });

  test('enrich keeps Empathy when Open Library is down', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('openlibrary.org')) return null;
        if (options.uri.host.contains('empathy.co')) {
          return _json(options, {
            'catalog': {
              'numFound': 1,
              'content': [
                {
                  'name': 'Carl el Mazmorrero',
                  'authors': ['Matt Dinniman'],
                  'ean': '9788410466135',
                  'image':
                      'https://imagessl1.casadellibro.com/a/l/t1/35/9788410466135.jpg',
                },
              ],
            },
          });
        }
        return _catalogReply(options);
      }),
    );
    final hit = await client.enrich(
      isbn: '9788410466135',
      title: 'Carl el Mazmorrero',
      authors: const ['Matt Dinniman'],
    );
    expect(hit?.title, 'Carl el Mazmorrero');
    expect(hit?.coverUrl, contains('casadellibro.com'));
  });

  test(
    'search prefers Spanish when Open Library lists mixed languages',
    () async {
      final client = CatalogClient(
        dio: _dio(
          (options) => _catalogReply(
            options,
            openLibrary: {
              'numFound': 1,
              'docs': [
                {
                  'title': 'Rayuela',
                  'author_name': ['Cortázar'],
                  'isbn': ['9788437604572'],
                  'language': ['eng', 'spa'],
                },
              ],
            },
          ),
        ),
      );
      final page = await client.search('Rayuela');
      expect(page.items, hasLength(1));
      expect(page.items.first.language, 'spa');
    },
  );

  test(
    'search keeps a delayed BNE hit instead of dropping it',
    () async {
      final client = CatalogClient(
        dio: _dio(
          (options) => _catalogReply(
            options,
            openLibrary: {
              'numFound': 1,
              'docs': [
                {
                  'title': 'Rayuela',
                  'author_name': ['Cortázar'],
                  'isbn': ['9788437604572'],
                  'language': ['spa'],
                },
              ],
            },
            bneXml:
                '<record><dc:title>Libro BNE</dc:title><dc:creator>Anon</dc:creator></record>',
          ),
          delayFor: (options) {
            if (options.uri.host.contains('catalogo.bne.es')) {
              return const Duration(milliseconds: 40);
            }
            return Duration.zero;
          },
        ),
      );
      final page = await client.search('Rayuela');
      expect(
        page.items.map((e) => e.title),
        containsAll(['Rayuela', 'Libro BNE']),
      );
    },
  );

  test(
    'search still returns Open Library when BNE exceeds the secondary timeout',
    () async {
      final client = CatalogClient(
        secondaryTimeout: const Duration(milliseconds: 40),
        dio: _dio(
          (options) => _catalogReply(
            options,
            openLibrary: {
              'numFound': 1,
              'docs': [
                {
                  'title': 'Rayuela',
                  'author_name': ['Cortázar'],
                  'isbn': ['9788437604572'],
                  'language': ['spa'],
                },
              ],
            },
          ),
          delayFor: (options) {
            if (options.uri.host.contains('catalogo.bne.es')) {
              return const Duration(milliseconds: 250);
            }
            return Duration.zero;
          },
        ),
      );
      final sw = Stopwatch()..start();
      final page = await client.search('Rayuela');
      sw.stop();
      expect(page.items, hasLength(1));
      expect(page.items.first.title, 'Rayuela');
      expect(sw.elapsedMilliseconds, lessThan(200));
    },
  );

  test('search returns BNE when Open Library is empty', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'numFound': 0,
            'docs': <Map<String, dynamic>>[],
          },
          bneXml:
              '<record><dc:title>Solo BNE</dc:title><dc:creator>Anon</dc:creator></record>',
        ),
      ),
    );
    final page = await client.search('Rayuela');
    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Solo BNE');
  });

  test(
    'ISBN lookup skips search.json and works.json when isbn.json is complete',
    () async {
      var searchJson = 0;
      var worksJson = 0;
      final client = CatalogClient(
        dio: _dio((options) {
          final path = options.uri.path;
          if (path.contains('search.json')) searchJson++;
          if (path.contains('/works/')) worksJson++;
          return _catalogReply(
            options,
            openLibrary: {
              'title': 'Rayuela',
              'authors': [
                {'name': 'Cortázar'},
              ],
              'covers': [99],
              'works': [
                {'key': '/works/OL123W'},
              ],
            },
          );
        }),
      );
      final hit = await client.lookupIsbn('9788437604572');
      expect(hit?.title, 'Rayuela');
      expect(hit?.authors, ['Cortázar']);
      expect(searchJson, 0);
      expect(worksJson, 0);
    },
  );

  test('ISBN lookup does not wait for a slow Wikidata blurb', () async {
    final client = CatalogClient(
      blurbTimeout: const Duration(milliseconds: 40),
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'title': 'Rayuela',
            'authors': [
              {'name': 'Cortázar'},
            ],
            'covers': [99],
          },
          wikidata: {
            'results': {
              'bindings': [
                {
                  'desc': {'value': 'Novela de Julio Cortázar'},
                },
              ],
            },
          },
        ),
        delayFor: (options) {
          if (options.uri.host.contains('query.wikidata.org')) {
            return const Duration(milliseconds: 250);
          }
          return Duration.zero;
        },
      ),
    );
    final sw = Stopwatch()..start();
    final hit = await client.lookupIsbn('9788437604572');
    sw.stop();
    expect(hit?.title, 'Rayuela');
    expect(hit?.description, isEmpty);
    expect(sw.elapsedMilliseconds, lessThan(200));
  });

  test('ISBN lookup trusts Open Library cover-id jackets', () async {
    final probed = <String>[];
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('covers.openlibrary')) {
          probed.add(options.uri.path);
        }
        return _catalogReply(
          options,
          openLibrary: {
            'title': 'Rayuela',
            'authors': [
              {'name': 'Cortázar'},
            ],
            'covers': [99],
          },
        );
      }),
    );
    final hit = await client.lookupIsbn('9788437604572');
    expect(hit?.coverUrl, contains('-L.jpg'));
    expect(probed, isEmpty);
  });

  test('ISBN lookup probes speculative ISBN cover URLs', () async {
    final probed = <Uri>[];
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('covers.openlibrary') ||
            options.uri.host.contains('casadellibro.com')) {
          probed.add(options.uri);
        }
        return _catalogReply(
          options,
          openLibrary: {
            'title': 'Rayuela',
            'authors': [
              {'name': 'Cortázar'},
            ],
          },
        );
      }),
    );
    final hit = await client.lookupIsbn('9788437604572');
    expect(hit?.coverUrl, contains('casadellibro.com'));
    expect(probed, isNotEmpty);
  });

  test(
    'search fills Casa del Libro covers from Empathy when OL is empty',
    () async {
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.host.contains('empathy.co')) {
            return _json(options, {
              'catalog': {
                'numFound': 1,
                'content': [
                  {
                    'name': 'Carl el Mazmorrero (Carl el Mazmorrero 1)',
                    'authors': ['Matt Dinniman', 'MATT DINNIMAN'],
                    'ean': '9788410466135',
                    'isbn': '8410466139',
                  },
                ],
              },
            });
          }
          return _catalogReply(
            options,
            openLibrary: {
              'numFound': 0,
              'docs': <Map<String, dynamic>>[],
            },
          );
        }),
      );
      final page = await client.search('Carl el mazmorrero');
      expect(page.items, isNotEmpty);
      expect(page.items.first.title, contains('Carl el Mazmorrero'));
      expect(page.items.first.authors, ['Matt Dinniman']);
      expect(page.items.first.isbn, '9788410466135');
      expect(page.items.first.coverUrl, contains('imagessl1.casadellibro.com'));
      expect(page.items.first.coverUrl, contains('9788410466135'));
    },
  );

  test('ISBN lookup keeps Empathy jacket when Open Library has none', () async {
    final client = CatalogClient(
      dio: _dio((options) {
        if (options.uri.host.contains('empathy.co')) {
          return _json(options, {
            'catalog': {
              'numFound': 1,
              'content': [
                {
                  'name': 'Carl el Mazmorrero',
                  'authors': ['Matt Dinniman'],
                  'ean': '9788410466135',
                },
              ],
            },
          });
        }
        return _catalogReply(options);
      }),
    );
    final hit = await client.lookupIsbn('9788410466135');
    expect(hit?.title, 'Carl el Mazmorrero');
    expect(hit?.coverUrl, contains('casadellibro.com'));
  });

  test('BNE search records keep ISBN and contributor names', () async {
    final client = CatalogClient(
      dio: _dio(
        (options) => _catalogReply(
          options,
          openLibrary: {
            'numFound': 0,
            'docs': <Map<String, dynamic>>[],
          },
          bneXml:
              '<record><dc:title>Carl el Mazmorrero</dc:title>'
              '<dc:contributor>Dinniman, Matt autor aut</dc:contributor>'
              '<dc:identifier>978-84-10466-13-5</dc:identifier></record>',
        ),
      ),
    );
    final page = await client.search('Carl el mazmorrero');
    expect(page.items, isNotEmpty);
    final carl = page.items.firstWhere(
      (h) => h.title == 'Carl el Mazmorrero',
    );
    expect(carl.authors, ['Dinniman, Matt']);
    expect(carl.isbn, '9788410466135');
    expect(carl.coverUrl, contains('casadellibro.com'));
  });

  test(
    'ISBN lookup uses Wikidata Commons image when catalogs have none',
    () async {
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.host.contains('query.wikidata.org')) {
            return _json(options, {
              'results': {
                'bindings': [
                  {
                    'img': {
                      'value':
                          'http://commons.wikimedia.org/wiki/Special:FilePath/Dune.jpg',
                    },
                  },
                ],
              },
            });
          }
          if (options.uri.host.contains('casadellibro.com') ||
              options.uri.host.contains('covers.openlibrary')) {
            return null;
          }
          return _catalogReply(
            options,
            openLibrary: {
              'title': 'Dune',
              'authors': [
                {'name': 'Frank Herbert'},
              ],
            },
          );
        }),
      );
      final hit = await client.lookupIsbn('9780441172719');
      expect(hit?.title, 'Dune');
      expect(hit?.coverUrl, contains('commons.wikimedia.org'));
      expect(hit?.coverUrl, startsWith('https://'));
    },
  );

  test(
    'Empathy maps synopsis, date, publisher, binding, and categories',
    () async {
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.host.contains('empathy.co')) {
            return _json(options, {
              'catalog': {
                'numFound': 1,
                'content': [
                  {
                    'name': 'Carl el Mazmorrero',
                    'subtitle': 'Dungeon Crawler Carl',
                    'authors': ['Matt Dinniman'],
                    'ean': '9788410466135',
                    'description':
                        'Carl entra en la mazmorra y no puede salir.',
                    'dateRelease': 1752105600,
                    'yearPublication': '2025',
                    'editorial': 'Nova',
                    'encuadernation': 'Tapa blanda',
                    'productType': 'Libro',
                    'idioma': 'Castellano',
                    'hierarchicalCategories':
                        'Libros>Literatura>Ciencia ficción',
                  },
                ],
              },
            });
          }
          return _catalogReply(
            options,
            openLibrary: {
              'numFound': 0,
              'docs': <Map<String, dynamic>>[],
            },
          );
        }),
      );
      final page = await client.search('Carl el mazmorrero');
      final hit = page.items.first;
      expect(hit.description, contains('mazmorra'));
      expect(hit.publisher, 'Nova');
      expect(hit.binding, 'Tapa blanda');
      expect(hit.format, 'physical');
      expect(hit.subtitle, 'Dungeon Crawler Carl');
      expect(hit.publicationDate, DateTime.utc(2025, 7, 10));
      expect(hit.publicationDatePrecision, 'day');
      expect(hit.categoryCodes, contains('science_fiction'));
    },
  );

  test(
    'Open Library search maps pages, subtitle, subjects, and year',
    () async {
      String? fields;
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.path.contains('search.json')) {
            fields = options.uri.queryParameters['fields'];
          }
          return _catalogReply(
            options,
            openLibrary: {
              'numFound': 1,
              'docs': [
                {
                  'title': 'Rayuela',
                  'subtitle': 'Novela',
                  'author_name': ['Cortázar'],
                  'isbn': ['9788437604572'],
                  'subject': ['Fiction'],
                  'number_of_pages_median': 736,
                  'first_publish_year': 1963,
                  'first_sentence': ['Encontraría a la Maga.'],
                  'publisher': ['Sudamericana'],
                  'language': ['spa'],
                },
              ],
            },
          );
        }),
      );
      final page = await client.search('Rayuela');
      expect(fields, contains('subtitle'));
      expect(fields, contains('first_publish_year'));
      expect(fields, contains('number_of_pages_median'));
      expect(page.items.first.pageCount, 736);
      expect(page.items.first.subtitle, 'Novela');
      expect(page.items.first.publisher, 'Sudamericana');
      expect(page.items.first.description, 'Encontraría a la Maga.');
      expect(page.items.first.publicationDate, DateTime.utc(1963));
      expect(page.items.first.publicationDatePrecision, 'year');
    },
  );

  test(
    'BNE DC maps description, date, subject, publisher, and pages',
    () async {
      final client = CatalogClient(
        dio: _dio(
          (options) => _catalogReply(
            options,
            openLibrary: {
              'numFound': 0,
              'docs': <Map<String, dynamic>>[],
            },
            bneXml:
                '<record><dc:title>Rayuela</dc:title>'
                '<dc:creator>Cortázar, Julio</dc:creator>'
                '<dc:identifier>978-84-376-0457-2</dc:identifier>'
                '<dc:description>Novela de la hopscotch.</dc:description>'
                '<dc:date>1963</dc:date>'
                '<dc:subject>Ficción</dc:subject>'
                '<dc:publisher>Cátedra</dc:publisher>'
                '<dc:format>736 p. ; 18 cm</dc:format>'
                '<dc:language>spa</dc:language></record>',
          ),
        ),
      );
      final page = await client.search('Rayuela');
      final hit = page.items.firstWhere((h) => h.title == 'Rayuela');
      expect(hit.description, 'Novela de la hopscotch.');
      expect(hit.publisher, 'Cátedra');
      expect(hit.pageCount, 736);
      expect(hit.publicationDate, DateTime.utc(1963));
      expect(hit.publicationDatePrecision, 'year');
      expect(hit.categoryCodes, contains('fiction'));
      expect(hit.language, 'spa');
    },
  );

  test(
    'ISBN lookup fills pages and date from Wikidata when catalogs omit them',
    () async {
      final client = CatalogClient(
        dio: _dio((options) {
          if (options.uri.host.contains('query.wikidata.org')) {
            return _json(options, {
              'results': {
                'bindings': [
                  {
                    'pages': {'value': '432'},
                    'date': {'value': '1965-08-01T00:00:00Z'},
                  },
                ],
              },
            });
          }
          return _catalogReply(
            options,
            openLibrary: {
              'title': 'Dune',
              'authors': [
                {'name': 'Frank Herbert'},
              ],
              'description': 'Arena y especia.',
            },
          );
        }),
      );
      final hit = await client.lookupIsbn('9780441172719');
      expect(hit?.title, 'Dune');
      expect(hit?.description, 'Arena y especia.');
      expect(hit?.pageCount, 432);
      expect(hit?.publicationDate, DateTime.utc(1965, 8, 1));
      expect(hit?.publicationDatePrecision, 'day');
    },
  );
}
