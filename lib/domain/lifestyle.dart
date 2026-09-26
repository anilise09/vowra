/// Optional lifestyle answers. One choice per topic; every topic can be left
/// blank. Local to the device for now: not yet part of the profile contract.
enum LifestyleTopic {
  drinking('Drinking', ['Never', 'Rarely', 'Socially', 'Often']),
  smoking('Smoking', ['No', 'Sometimes', 'Yes', 'Trying to quit']),
  exercise('Exercise', ['Daily', 'Most weeks', 'Now and then', 'Rarely']),
  pets('Pets', [
    'Dog person',
    'Cat person',
    'Other pets',
    'No pets',
    'Want one',
  ]);

  const LifestyleTopic(this.label, this.options);
  final String label;
  final List<String> options;
}
