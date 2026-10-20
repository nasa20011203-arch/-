class AppSettings {
  const AppSettings({
    this.x = 100,
    this.y = 100,
    this.width = 980,
    this.height = 720,
    this.opacity = 0.9,
    this.fontSize = 14,
    this.autoStart = false,
    this.desktopMode = false,
  });
  final double x, y, width, height, opacity, fontSize;
  final bool autoStart, desktopMode;

  AppSettings copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? opacity,
    double? fontSize,
    bool? autoStart,
    bool? desktopMode,
  }) => AppSettings(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    opacity: opacity ?? this.opacity,
    fontSize: fontSize ?? this.fontSize,
    autoStart: autoStart ?? this.autoStart,
    desktopMode: desktopMode ?? this.desktopMode,
  );

  Map<String, Object> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'opacity': opacity,
    'fontSize': fontSize,
    'autoStart': autoStart,
    'desktopMode': desktopMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback, double min, double max) {
      final value = json[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.toDouble().clamp(min, max);
    }

    return AppSettings(
      x: number('x', 100, -100000, 100000),
      y: number('y', 100, -100000, 100000),
      width: number('width', 980, 560, 10000),
      height: number('height', 720, 420, 10000),
      opacity: number('opacity', 0.9, 0.15, 1),
      fontSize: number('fontSize', 14, 10, 28),
      autoStart: json['autoStart'] == true,
      desktopMode: json['desktopMode'] == true,
    );
  }
}
