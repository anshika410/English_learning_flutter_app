// Engine constants — must match ella-loop-sim-2.html exactly.
// Change nothing here without updating the simulator and the unit tests.

const double kFloor = 0.3;

const Map<String, double> kOwnBar = {
  'A1': 0.55,
  'A2': 0.60,
  'B1': 0.68,
  'B2': 0.72,
  'C1': 0.75,
  'C2': 0.78,
};

const int kSightingsToOwn = 2;

const List<String> kCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

double ownBarFor(String level) => kOwnBar[level] ?? 0.70;
