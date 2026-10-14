/// Data models for assets/data/joypurhat.json.
library;

import 'dart:ui' show Color;

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

String _s(dynamic v) => v == null ? '' : v.toString();

double? _d(dynamic v) => v is num ? v.toDouble() : null;

class FieldDef {
  FieldDef({
    required this.key,
    required this.type,
    required this.label,
    this.hint = '',
    this.required = false,
    this.options = const [],
    this.descriptions = const [],
    this.min = 0,
    this.max = 0,
    this.defaultValue = 0,
    this.step = 1,
    this.unit = '',
    this.whenKey = '',
    this.whenValue = 0,
    this.fromServices = false,
    this.count = 0,
  });

  /// text, tel, area, chips, dates, docdates, step, choice, slots, photo
  final String key;
  final String type;
  final String label;
  final String hint;
  final bool required;
  final List<String> options;
  final List<String> descriptions;
  final int min;
  final int max;
  final int defaultValue;
  final int step;
  final String unit;

  /// Shown only while the field [whenKey] has choice [whenValue], like the
  /// delivery address for home delivery.
  final String whenKey;
  final int whenValue;

  /// Options come from the place's own services; hidden when it has none.
  final bool fromServices;

  /// How many days a date field offers (0: a week).
  final int count;

  factory FieldDef.fromJson(String key, Map<String, dynamic> j) => FieldDef(
        key: key,
        type: _s(j['type']),
        label: _s(j['label']),
        hint: _s(j['hint']),
        required: j['required'] == true,
        options: _strings(j['options']),
        descriptions: (j['descriptions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        min: (j['min'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt() ?? 0,
        defaultValue: (j['default'] as num?)?.toInt() ?? 0,
        step: (j['step'] as num?)?.toInt() ?? 1,
        unit: _s(j['unit']),
        whenKey: _s(j['whenKey']),
        whenValue: (j['whenValue'] as num?)?.toInt() ?? 0,
        fromServices: j['fromServices'] == true,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class FormConfig {
  FormConfig({
    required this.title,
    required this.fields,
    this.button = '',
    this.sub = '',
    this.intro = '',
    this.cta = '',
    this.doneTitle = '',
    this.message = '',
    this.bigLabel = '',
    this.serial = false,
    this.track = false,
    this.bannerTitle = '',
    this.bannerSub = '',
  });

  final String title;
  final List<FieldDef> fields;
  final String button;
  final String sub;
  final String intro;
  final String cta;
  final String doneTitle;
  final String message;
  final String bigLabel;
  final bool serial;

  /// Food orders: the demo shows a step-by-step order tracker afterwards.
  final bool track;

  /// The invitation card on a list screen that opens this form (To-Let).
  final String bannerTitle;
  final String bannerSub;

  static FormConfig? fromJson(dynamic j, Map<String, FieldDef> shared) {
    if (j is! Map<String, dynamic>) return null;
    final fields = <FieldDef>[];
    for (final f in (j['fields'] as List? ?? const [])) {
      if (f is String) {
        final def = shared[f];
        if (def != null) fields.add(def);
      } else if (f is Map<String, dynamic>) {
        fields.add(FieldDef.fromJson(_s(f['key']), f));
      }
    }
    return FormConfig(
      title: _s(j['title']),
      fields: fields,
      button: _s(j['button']),
      sub: _s(j['sub']),
      intro: _s(j['intro']),
      cta: _s(j['cta']),
      doneTitle: _s(j['doneTitle']),
      message: _s(j['message']),
      bigLabel: _s(j['bigLabel']),
      serial: j['serial'] == true,
      track: j['track'] == true,
      bannerTitle: _s(j['bannerTitle']),
      bannerSub: _s(j['bannerSub']),
    );
  }
}

class InfoRow {
  const InfoRow(this.label, this.value, this.icon);
  final String label;
  final String value;
  final String icon;

  factory InfoRow.fromJson(Map<String, dynamic> j) =>
      InfoRow(_s(j['label']), _s(j['value']), _s(j['icon']));
}

class MenuRow {
  const MenuRow({required this.name, this.sub = '', this.price = '', this.phone = '', this.url = ''});
  final String name;
  final String sub;
  final String price;
  final String phone;
  final String url;

  factory MenuRow.fromJson(Map<String, dynamic> j) => MenuRow(
        name: _s(j['name']),
        sub: _s(j['sub']),
        price: _s(j['price']),
        phone: _s(j['phone']),
        url: _s(j['url']),
      );
}

class LinkInfo {
  const LinkInfo(this.label, this.url);
  final String label;
  final String url;
}

/// A website listed under a service, e.g. online to-let ads.
class WebLink {
  const WebLink(this.label, this.sub, this.url);
  final String label;
  final String sub;
  final String url;
}

/// A real photo of a place: a bundled file under assets/photos/ or a web
/// address, with the credit (photographer and licence) shown under it.
class Photo {
  const Photo(this.src, {this.credit = ''});
  final String src;
  final String credit;

  bool get isWeb => src.startsWith('https://') || src.startsWith('http://');

  static Photo? fromJson(dynamic j) {
    if (j is String) return j.isEmpty ? null : Photo(j);
    if (j is Map) {
      final src = _s(j['src']);
      return src.isEmpty ? null : Photo(src, credit: _s(j['credit']));
    }
    return null;
  }
}

/// A dish on a restaurant menu (sample restaurants in demo mode only).
class Dish {
  const Dish({required this.name, this.desc = '', required this.price, this.art = ''});
  final String name;
  final String desc;
  final int price;

  /// Picture kind for the drawn plate: rice, curry, fish, sweet, ...
  final String art;

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        name: _s(j['name']),
        desc: _s(j['desc']),
        price: (j['price'] as num?)?.toInt() ?? 0,
        art: _s(j['art']),
      );
}

class MenuSection {
  const MenuSection(this.title, this.dishes);
  final String title;
  final List<Dish> dishes;
}

/// A flat, room or seat in a To-Let listing.
class RentUnit {
  const RentUnit({required this.name, this.sub = '', this.rent = '', this.free = false});
  final String name;
  final String sub;
  final String rent;
  final bool free;

  factory RentUnit.fromJson(Map<String, dynamic> j) =>
      RentUnit(name: _s(j['name']), sub: _s(j['sub']), rent: _s(j['rent']), free: j['free'] == true);
}

class Vacancy {
  const Vacancy({required this.total, required this.vacant, this.unit = 'রুম'});
  final int total;
  final int vacant;
  final String unit;
}

Color? _hex(dynamic v) {
  final s = _s(v);
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s)) return null;
  return Color(int.parse('FF${s.substring(1)}', radix: 16));
}

List<Color> _colors(dynamic v) => [
      if (v is List)
        for (final e in v)
          if (_hex(e) != null) _hex(e)!,
    ];

/// One place where a doctor sees patients.
class Chamber {
  const Chamber({
    required this.name,
    this.address = '',
    this.upazila = '',
    this.days = '',
    this.time = '',
    this.fee = '',
    this.phones = const [],
    this.weekdays = const [],
  });

  final String name;
  final String address;
  final String upazila;
  final String days;
  final String time;
  final String fee;
  final List<String> phones;

  /// Days the doctor sits, 0 Sunday ... 6 Saturday, when known.
  final List<int> weekdays;

  factory Chamber.fromJson(Map<String, dynamic> j) => Chamber(
        name: _s(j['name']),
        address: _s(j['address']),
        upazila: _s(j['upazila']),
        days: _s(j['days']),
        time: _s(j['time']),
        fee: _s(j['fee']),
        phones: _strings(j['phones']),
      );

  String get schedule => [days, time].where((e) => e.isNotEmpty).join(', ');
}

class Doctor {
  Doctor({
    required this.index,
    required this.name,
    this.nameEn = '',
    this.degrees = '',
    this.specialty = '',
    this.group = 'অন্যান্য',
    this.designation = '',
    this.chambers = const [],
    this.confidence = '',
    this.sources = const [],
  });

  final int index;
  final String name;
  final String nameEn;
  final String degrees;
  final String specialty;
  final String group;
  final String designation;
  final List<Chamber> chambers;
  final String confidence;
  final List<String> sources;

  factory Doctor.fromJson(int index, Map<String, dynamic> j) => Doctor(
        index: index,
        name: _s(j['name']),
        nameEn: _s(j['nameEn']),
        degrees: _s(j['degrees']),
        specialty: _s(j['specialty']),
        group: _s(j['group']).isEmpty ? 'অন্যান্য' : _s(j['group']),
        designation: _s(j['designation']),
        chambers: (j['chambers'] as List? ?? const [])
            .map((c) => Chamber.fromJson(c as Map<String, dynamic>))
            .toList(),
        confidence: _s(j['confidence']),
        sources: _strings(j['sources']),
      );

  String get searchText => '$name $nameEn $degrees $specialty $group $designation '
          '${chambers.map((c) => '${c.name} ${c.address}').join(' ')}'
      .toLowerCase();
}

/// A doctor as listed at one centre, with that centre's schedule.
class DoctorAtPlace {
  const DoctorAtPlace(this.doctor, this.chamber);
  final Doctor doctor;
  final Chamber chamber;
}

class Item {
  Item({
    required this.id,
    required this.name,
    this.sub = '',
    this.nameEn = '',
    this.tag = '',
    this.address = '',
    this.phones = const [],
    this.time = '',
    this.price = '',
    this.rows = const [],
    this.chips = const [],
    this.about = '',
    this.note = '',
    this.menu = const [],
    this.menuTitle = '',
    this.website = '',
    this.link,
    this.mapQuery = '',
    this.lat,
    this.lng,
    this.icon = '',
    this.sources = const [],
    this.confidence = '',
    this.sample = false,
    this.showMap = true,
    this.book,
    this.doctorRefs = const [],
    this.inlineDoctors = const [],
    this.checked = '',
    this.howTo = '',
    this.menuNote = '',
    this.art = '',
    this.arts = const [],
    this.foodMenu = const [],
    this.deliveryFee = 0,
    this.deliveryTime = '',
    this.cover = const [],
    this.palette = const [],
    this.rent = '',
    this.per = '',
    this.facts = const [],
    this.vacancy,
    this.units = const [],
    this.updated = '',
    this.bookedSlots = const [],
    this.photos = const [],
  });

  final String id;
  final String name;
  final String sub;
  final String nameEn;
  final String tag;
  final String address;
  final List<String> phones;
  final String time;
  final String price;
  final List<InfoRow> rows;
  final List<String> chips;
  final String about;
  final String note;
  final List<MenuRow> menu;
  final String menuTitle;
  final String website;
  final LinkInfo? link;
  final String mapQuery;
  final double? lat;
  final double? lng;
  final String icon;
  final List<String> sources;
  final String confidence;
  final bool sample;
  final bool showMap;
  final FormConfig? book;
  final List<(int, int)> doctorRefs;
  final List<Map<String, dynamic>> inlineDoctors;

  /// The date this entry was last checked, when newer than the catalog's.
  final String checked;

  /// How to get there (tourist spots).
  final String howTo;

  /// A dated note under a menu, e.g. where the prices were seen.
  final String menuNote;

  /// Drawn picture for places without a photo yet: the first scene, then
  /// more scenes for the gallery.
  final String art;
  final List<String> arts;

  /// Restaurant ordering (sample restaurants only).
  final List<MenuSection> foodMenu;
  final int deliveryFee;
  final String deliveryTime;
  final List<Color> cover;
  final List<Color> palette;

  /// Rent listings.
  final String rent;
  final String per;
  final List<String> facts;
  final Vacancy? vacancy;
  final List<RentUnit> units;
  final String updated;

  /// Time slots already taken, per day (sample parlours only).
  final List<List<String>> bookedSlots;

  /// Real photos, when added (data_sources/photos.json). Without them the
  /// app shows drawn pictures marked "ছবি যোগ হবে".
  final List<Photo> photos;

  /// Filled in by the catalog after loading.
  List<DoctorAtPlace> doctors = const [];

  bool get isLowConfidence => confidence == 'low';

  bool get hasMenu => foodMenu.any((s) => s.dishes.isNotEmpty);

  /// All scenes for the gallery, first one first.
  List<String> get scenes => [if (art.isNotEmpty) art, ...arts];

  String get searchText =>
      '$name $sub $nameEn $tag $address ${chips.join(' ')}'.toLowerCase();

  factory Item.fromJson(String id, Map<String, dynamic> j, Map<String, FieldDef> shared) {
    final link = j['link'];
    return Item(
      id: id,
      name: _s(j['name']),
      sub: _s(j['sub']),
      nameEn: _s(j['nameEn']),
      tag: _s(j['tag']),
      address: _s(j['address']),
      phones: _strings(j['phones']),
      time: _s(j['time']),
      price: _s(j['price']),
      rows: (j['rows'] as List? ?? const [])
          .map((r) => InfoRow.fromJson(r as Map<String, dynamic>))
          .toList(),
      chips: _strings(j['chips']),
      about: _s(j['about']),
      note: _s(j['note']),
      menu: (j['menu'] as List? ?? const [])
          .map((r) => MenuRow.fromJson(r as Map<String, dynamic>))
          .toList(),
      menuTitle: _s(j['menuTitle']),
      website: _s(j['website']),
      link: link is Map ? LinkInfo(_s(link['label']), _s(link['url'])) : null,
      mapQuery: _s(j['mapQuery']),
      lat: _d(j['lat']),
      lng: _d(j['lng']),
      icon: _s(j['icon']),
      sources: _strings(j['sources']),
      confidence: _s(j['confidence']),
      sample: j['sample'] == true,
      showMap: j['showMap'] != false,
      book: FormConfig.fromJson(j['book'], shared),
      doctorRefs: (j['doctorRefs'] as List? ?? const [])
          .map((r) => ((r['doctor'] as num).toInt(), (r['chamber'] as num).toInt()))
          .toList(),
      inlineDoctors: (j['doctors'] as List? ?? const []).cast<Map<String, dynamic>>(),
      checked: _s(j['checked']),
      howTo: _s(j['howTo']),
      menuNote: _s(j['menuNote']),
      art: _s(j['art']),
      arts: _strings(j['arts']),
      foodMenu: [
        for (final sec in (j['foodMenu'] as List? ?? const []))
          MenuSection(
            _s(sec['title']),
            (sec['items'] as List? ?? const []).map((d) => Dish.fromJson(d as Map<String, dynamic>)).toList(),
          ),
      ],
      deliveryFee: (j['deliveryFee'] as num?)?.toInt() ?? 0,
      deliveryTime: _s(j['deliveryTime']),
      cover: _colors(j['cover']),
      palette: _colors(j['palette']),
      rent: _s(j['rent']),
      per: _s(j['per']),
      facts: _strings(j['facts']),
      vacancy: j['vacancy'] is Map
          ? Vacancy(
              total: (j['vacancy']['total'] as num).toInt(),
              vacant: (j['vacancy']['vacant'] as num).toInt(),
              unit: _s(j['vacancy']['unit']).isEmpty ? 'রুম' : _s(j['vacancy']['unit']),
            )
          : null,
      units: (j['units'] as List? ?? const []).map((u) => RentUnit.fromJson(u as Map<String, dynamic>)).toList(),
      updated: _s(j['updated']),
      bookedSlots: [for (final day in (j['bookedSlots'] as List? ?? const [])) _strings(day)],
      photos: (j['photos'] as List? ?? const []).map(Photo.fromJson).whereType<Photo>().toList(),
    );
  }
}

class CallEntry {
  const CallEntry({
    required this.name,
    this.sub = '',
    this.numbers = const [],
    this.icon = '',
    this.note = '',
    this.confidence = '',
    this.sources = const [],
  });

  final String name;
  final String sub;
  final List<String> numbers;
  final String icon;
  final String note;
  final String confidence;
  final List<String> sources;

  factory CallEntry.fromJson(Map<String, dynamic> j) => CallEntry(
        name: _s(j['name']),
        sub: _s(j['sub']),
        numbers: _strings(j['numbers']),
        icon: _s(j['icon']),
        note: _s(j['note']),
        confidence: _s(j['confidence']),
        sources: _strings(j['sources']),
      );
}

class CallSection {
  const CallSection(this.title, this.items);
  final String title;
  final List<CallEntry> items;
}

class Article {
  const Article({
    required this.title,
    required this.sub,
    required this.facts,
    required this.parts,
    required this.groups,
    required this.source,
  });

  final String title;
  final String sub;
  final List<(String, String)> facts;
  final List<(String, String)> parts;
  final List<(String, List<String>)> groups;
  final String source;

  factory Article.fromJson(Map<String, dynamic> j) => Article(
        title: _s(j['title']),
        sub: _s(j['sub']),
        facts: (j['facts'] as List).map((f) => (_s(f['label']), _s(f['value']))).toList(),
        parts: (j['parts'] as List).map((p) => (_s(p['title']), _s(p['text']))).toList(),
        groups: (j['groups'] as List).map((g) => (_s(g['title']), _strings(g['chips']))).toList(),
        source: _s(j['source']),
      );
}

class Product {
  const Product({
    required this.name,
    required this.unit,
    required this.price,
    required this.icon,
    required this.seller,
    this.sample = false,
  });

  final String name;
  final String unit;
  final int price;
  final String icon;
  final String seller;
  final bool sample;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        name: _s(j['name']),
        unit: _s(j['unit']),
        price: (j['price'] as num).toInt(),
        icon: _s(j['icon']),
        seller: _s(j['seller']),
        sample: j['sample'] == true,
      );
}

class Category {
  Category({
    required this.key,
    required this.label,
    required this.icon,
    required this.template,
    required this.title,
    this.keywords = '',
    this.unit = '',
    this.filters = const [],
    this.labels = const {},
    this.note = '',
    this.chipsTitle = '',
    this.aboutTitle = '',
    this.menuTitle = '',
    this.menuLabel = '',
    this.menuBook = false,
    this.menuButton = '',
    this.itemLabel = '',
    this.card = '',
    this.intro = '',
    this.tips = const [],
    this.tipsTitle = '',
    this.mode = '',
    this.showMap = true,
    this.book,
    this.order,
    this.form,
    this.hero,
    this.sections = const [],
    this.article,
    this.products = const [],
    this.emptyText = '',
    this.items = const [],
    this.color = 'teal',
    this.post,
    this.links = const [],
  });

  final String key;
  final String label;
  final String icon;

  /// call, list, doc, transport, article, shop, form
  final String template;
  final String title;
  final String keywords;
  final String unit;
  final List<String> filters;
  final Map<String, String> labels;
  final String note;
  final String chipsTitle;
  final String aboutTitle;
  final String menuTitle;
  final String menuLabel;
  final bool menuBook;
  final String menuButton;
  final String itemLabel;
  final String card;
  final String intro;
  final List<String> tips;
  final String tipsTitle;
  final String mode;
  final bool showMap;
  final FormConfig? book;
  final FormConfig? order;
  final FormConfig? form;
  final CallEntry? hero;
  final List<CallSection> sections;
  final Article? article;
  final List<Product> products;
  final String emptyText;
  final List<Item> items;

  /// Colour group name for the tile and accents (see Group in theme.dart).
  final String color;

  /// The To-Let form for landlords (house and mess).
  final FormConfig? post;

  /// Other websites worth opening for this service (shown under the note).
  final List<WebLink> links;

  String labelFor(String key, String fallback) => labels[key] ?? fallback;

  bool get isMedical => key == 'hospital' || key == 'diagnostic' || key == 'dental';

  factory Category.fromJson(String key, Map<String, dynamic> j, Map<String, FieldDef> shared) {
    final hero = j['hero'];
    final items = <Item>[];
    final rawItems = j['items'] as List? ?? const [];
    for (var i = 0; i < rawItems.length; i++) {
      items.add(Item.fromJson('$key#$i', rawItems[i] as Map<String, dynamic>, shared));
    }
    return Category(
      key: key,
      label: _s(j['label']),
      icon: _s(j['icon']),
      template: _s(j['template']),
      title: _s(j['title']).isEmpty ? _s(j['label']) : _s(j['title']),
      keywords: _s(j['keywords']),
      unit: _s(j['unit']),
      filters: _strings(j['filters']),
      labels: (j['labels'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
      note: _s(j['note']),
      chipsTitle: _s(j['chipsTitle']),
      aboutTitle: _s(j['aboutTitle']),
      menuTitle: _s(j['menuTitle']),
      menuLabel: _s(j['menuLabel']),
      menuBook: j['menuBook'] == true,
      menuButton: _s(j['menuButton']),
      itemLabel: _s(j['itemLabel']),
      card: _s(j['card']),
      intro: _s(j['intro']),
      tips: _strings(j['tips']),
      tipsTitle: _s(j['tipsTitle']),
      mode: _s(j['mode']),
      showMap: j['showMap'] != false,
      book: FormConfig.fromJson(j['book'], shared),
      order: FormConfig.fromJson(j['order'], shared),
      form: FormConfig.fromJson(j['form'], shared),
      hero: hero is Map<String, dynamic> ? CallEntry.fromJson(hero) : null,
      sections: (j['sections'] as List? ?? const [])
          .map((s) => CallSection(
                _s(s['title']),
                (s['items'] as List).map((e) => CallEntry.fromJson(e as Map<String, dynamic>)).toList(),
              ))
          .toList(),
      article: j['article'] is Map<String, dynamic> ? Article.fromJson(j['article']) : null,
      products: (j['products'] as List? ?? const [])
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList(),
      emptyText: _s(j['emptyText']),
      items: items,
      color: _s(j['color']).isEmpty ? 'teal' : _s(j['color']),
      post: FormConfig.fromJson(j['post'], shared),
      links: [
        for (final l in (j['links'] as List? ?? const []))
          if (l is Map && _s(l['url']).startsWith('https://')) WebLink(_s(l['label']), _s(l['sub']), _s(l['url'])),
      ],
    );
  }
}

class Notice {
  const Notice({required this.id, required this.title, required this.date, required this.body});
  final String id;
  final String title;
  final String date;
  final String body;

  factory Notice.fromJson(Map<String, dynamic> j) =>
      Notice(id: _s(j['id']), title: _s(j['title']), date: _s(j['date']), body: _s(j['body']));
}

/// A labelled group of services on the home screen.
class HomeSection {
  const HomeSection({required this.title, required this.sub, required this.color, required this.icon, required this.keys});
  final String title;
  final String sub;
  final String color;
  final String icon;
  final List<String> keys;

  factory HomeSection.fromJson(Map<String, dynamic> j) => HomeSection(
        title: _s(j['title']),
        sub: _s(j['sub']),
        color: _s(j['color']),
        icon: _s(j['icon']),
        keys: _strings(j['keys']),
      );
}

/// One line of the scrolling announcement on the home screen.
class TickerLine {
  const TickerLine(this.text, this.color);
  final String text;
  final String color;
}
