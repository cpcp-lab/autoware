# Measure how old /control/trajectory_follower/control_cmd stamps are when they reach Autoware,
# and how far they lag behind the latest /planning/trajectory stamp (= delay through Simulink).
# Run inside the Autoware container while Autoware and dumb_control.slx are running:
#   python3 stamp_probe.py

import rclpy, statistics, time
from rclpy.node import Node
from autoware_control_msgs.msg import Control
from autoware_planning_msgs.msg import Trajectory

def t(s): return s.sec + s.nanosec * 1e-9

class P(Node):
    def __init__(self):
        super().__init__('stamp_probe')
        self.traj = None
        self.age, self.lag = [], []
        self.create_subscription(Trajectory, '/planning/trajectory', self.on_traj, 10)
        self.create_subscription(Control, '/control/trajectory_follower/control_cmd', self.on_ctl, 10)
    def on_traj(self, m): self.traj = t(m.header.stamp)
    def on_ctl(self, m):
        now = self.get_clock().now().nanoseconds * 1e-9
        s = t(m.stamp)
        self.age.append(now - s)
        if self.traj is not None: self.lag.append(self.traj - s)

rclpy.init(); n = P(); end = time.time() + 10
while time.time() < end: rclpy.spin_once(n, timeout_sec=0.1)
def summ(x): return f"n={len(x)} min={min(x):.3f} median={statistics.median(x):.3f} max={max(x):.3f}" if x else "no data"
print("control_cmd age (now - stamp):           ", summ(n.age))
print("latest trajectory stamp - control stamp: ", summ(n.lag))
