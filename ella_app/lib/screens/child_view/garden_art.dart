// Isometric garden art — SVG strings ported 1:1 from ella-garden-nonlinear.html
// (tileSVG, plotWrap, hut, well, windmill, emptyplot, buildingFor).
// Pure Dart: each function returns an SVG document string rendered via
// SvgPicture.string in garden_screen.dart. No Flutter imports here.
//
// State values match engine.gardenStateOf: 0 empty · 1 emerging · 2 growing · 3 owned.

const _xmlns = 'xmlns="http://www.w3.org/2000/svg"';

/// One isometric soil tile with its plant for the given [state] (0..3).
String tileSvg(int state) {
  final grass = state == 3;
  final top1 = grass ? '#BCE98C' : '#E9D4A8';
  final top2 = grass ? '#A4DC6A' : '#DCC18E';
  final sideL = grass ? '#86C24E' : '#C5A472';
  final sideR = grass ? '#74B040' : '#B3925F';
  final outline = grass ? '#5E9A30' : '#9C7E4E';

  final String p;
  switch (state) {
    case 1: // emerging — a small sprout
      p = '<path d="M30 60 L30 48" stroke="#4E9A00" stroke-width="2.6" stroke-linecap="round"/>'
          '<path d="M30 50 Q22 47 21 39 Q29 40 30 48 Z" fill="#9BD55E" stroke="#4E9A00" stroke-width="1"/>'
          '<path d="M30 52 Q38 49 39 42 Q31 43 30 50 Z" fill="#B5E47E" stroke="#4E9A00" stroke-width="1"/>';
      break;
    case 2: // growing — taller stem with a bud
      p = '<path d="M30 60 L30 36" stroke="#4E9A00" stroke-width="2.8" stroke-linecap="round"/>'
          '<path d="M30 50 Q20 47 18 38 Q28 39 30 48 Z" fill="#8FCC52" stroke="#4E9A00" stroke-width="1"/>'
          '<path d="M30 44 Q40 41 42 32 Q32 33 30 42 Z" fill="#8FCC52" stroke="#4E9A00" stroke-width="1"/>'
          '<ellipse cx="30" cy="32" rx="5.5" ry="7" fill="#FFB8C8" stroke="#C82050" stroke-width="1.4"/>';
      break;
    case 3: // owned — full bloom
      p = '<path d="M30 60 L30 34" stroke="#4E9A00" stroke-width="3" stroke-linecap="round"/>'
          '<path d="M30 52 Q19 49 17 39 Q28 40 30 50 Z" fill="#8FCC52" stroke="#4E9A00" stroke-width="1"/>'
          '<path d="M30 46 Q41 43 43 34 Q32 35 30 44 Z" fill="#8FCC52" stroke="#4E9A00" stroke-width="1"/>'
          '<g stroke="#C82050" stroke-width="1.2">'
          '<circle cx="30" cy="16" r="6" fill="#FF7DA0"/>'
          '<circle cx="22" cy="22" r="6" fill="#FF7DA0"/>'
          '<circle cx="38" cy="22" r="6" fill="#FF7DA0"/>'
          '<circle cx="25" cy="29" r="6" fill="#FF94B2"/>'
          '<circle cx="35" cy="29" r="6" fill="#FF94B2"/></g>'
          '<circle cx="30" cy="23" r="5" fill="#FFD699" stroke="#C87000" stroke-width="1.2"/>';
      break;
    default: // empty — bare soil pebbles
      p = '<g fill="#C9A876">'
          '<ellipse cx="24" cy="58" rx="3" ry="1.4"/>'
          '<ellipse cx="36" cy="62" rx="3.6" ry="1.6"/>'
          '<ellipse cx="30" cy="66" rx="2.6" ry="1.2"/></g>';
  }

  return '<svg $_xmlns width="40" height="61" viewBox="0 0 60 92">'
      '<polygon points="2,61 30,75 30,87 2,73" fill="$sideL"/>'
      '<polygon points="58,61 30,75 30,87 58,73" fill="$sideR"/>'
      '<polygon points="30,46 58,61 30,76 2,61" fill="$top1" stroke="$outline" stroke-width="1.6"/>'
      '<polygon points="30,52 46,61 30,70 14,61" fill="$top2" opacity="0.55"/>'
      '$p</svg>';
}

String _plotWrap(String inner) =>
    '<svg $_xmlns width="72" height="72" viewBox="0 0 118 118">'
    '<polygon points="6,79 59,106 59,116 6,89" fill="#C5A472"/>'
    '<polygon points="112,79 59,106 59,116 112,89" fill="#B3925F"/>'
    '<polygon points="59,52 112,79 59,106 6,79" fill="#D9EFB4" stroke="#8FBF5A" stroke-width="1.8"/>'
    '$inner</svg>';

String _emptyPlot() => _plotWrap(
    '<g fill="#A8C97E"><ellipse cx="45" cy="78" rx="4" ry="1.8"/><ellipse cx="70" cy="84" rx="4.6" ry="2"/></g>');

String _hut() => _plotWrap(
    '<polygon points="40,58 40,84 59,93 59,67" fill="#B8854E" stroke="#7A5226" stroke-width="1.4"/>'
    '<polygon points="78,58 78,84 59,93 59,67" fill="#D2A268" stroke="#7A5226" stroke-width="1.4"/>'
    '<polygon points="34,62 59,42 59,70" fill="#8A5E32" stroke="#5E3D1A" stroke-width="1.4"/>'
    '<polygon points="84,62 59,42 59,70" fill="#A4733E" stroke="#5E3D1A" stroke-width="1.4"/>');

String _well() => _plotWrap(
    '<polygon points="46,64 46,82 59,89 59,71" fill="#B8854E" stroke="#7A5226" stroke-width="1.2"/>'
    '<polygon points="72,64 72,82 59,89 59,71" fill="#D2A268" stroke="#7A5226" stroke-width="1.2"/>'
    '<polygon points="41,67 59,53 59,73" fill="#8A5E32" stroke="#5E3D1A" stroke-width="1.2"/>'
    '<polygon points="77,67 59,53 59,73" fill="#A4733E" stroke="#5E3D1A" stroke-width="1.2"/>'
    '<ellipse cx="88" cy="86" rx="11" ry="5.2" fill="#9FB6C2" stroke="#56707C" stroke-width="1.4"/>'
    '<path d="M77 86 L77 79 Q88 73 99 79 L99 86" fill="#B9CCD6" stroke="#56707C" stroke-width="1.4"/>');

// Note: the HTML windmill blades spin via CSS animation; here they are static.
String _windmill() => _plotWrap(
    '<polygon points="46,68 46,84 59,91 59,75" fill="#B8854E" stroke="#7A5226" stroke-width="1.2"/>'
    '<polygon points="72,68 72,84 59,91 59,75" fill="#D2A268" stroke="#7A5226" stroke-width="1.2"/>'
    '<polygon points="42,71 59,58 59,77" fill="#8A5E32" stroke="#5E3D1A" stroke-width="1.2"/>'
    '<polygon points="76,71 59,58 59,77" fill="#A4733E" stroke="#5E3D1A" stroke-width="1.2"/>'
    '<polygon points="84,88 87,52 95,52 98,88" fill="#EBDCB8" stroke="#9A8048" stroke-width="1.4"/>'
    '<g transform="translate(91,54)">'
    '<rect x="-2.2" y="-18" width="4.4" height="16" rx="2" fill="#D8463C"/>'
    '<rect x="2" y="-2.2" width="16" height="4.4" rx="2" fill="#D8463C"/>'
    '<rect x="-2.2" y="2" width="4.4" height="16" rx="2" fill="#D8463C"/>'
    '<rect x="-18" y="-2.2" width="16" height="4.4" rx="2" fill="#D8463C"/>'
    '<circle r="3" fill="#7A4400"/></g>');

/// Building for a bed, chosen by how many of its tiles are owned (state 3).
/// >=100% windmill · >=50% well · any sprout hut · else empty plot.
String buildingSvg(List<int> states) {
  if (states.isEmpty) return _emptyPlot();
  final owned = states.where((c) => c == 3).length;
  final ratio = owned / states.length;
  if (ratio >= 1) return _windmill();
  if (ratio >= 0.5) return _well();
  if (states.any((c) => c > 0)) return _hut();
  return _emptyPlot();
}
