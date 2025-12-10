/// A simple Spring physics simulation ported from the original JS implementation.
class SpringSimulation {
  double stiffness;
  double damping;
  double mass;

  double current;
  double target;
  double velocity;

  SpringSimulation({
    this.stiffness = 120.0,
    this.damping = 16.0,
    this.mass = 1.0,
    double initialValue = 0.0,
  }) : current = initialValue,
       target = initialValue,
       velocity = 0.0;

  void set(double value) {
    current = value;
    target = value;
    velocity = 0.0;
  }

  void update(double dt) {
    final double displacement = current - target;

    // Epsilon check to avoid persistent micro-jitters
    if (displacement.abs() < 0.001 && velocity.abs() < 0.001) {
      current = target;
      velocity = 0.0;
      return;
    }

    final double force = -stiffness * displacement - damping * velocity;
    final double acceleration = force / mass;

    velocity += acceleration * dt;
    current += velocity * dt;
  }
}
