# Snapshot of the signals that decide whether the vehicle starts moving.
# Run inside the Autoware container while Autoware and the Simulink controller are running:
#   python3 control_probe.py [seconds]
import math
import sys
import time

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, DurabilityPolicy, ReliabilityPolicy
from autoware_adapi_v1_msgs.msg import OperationModeState
from autoware_control_msgs.msg import Control
from autoware_planning_msgs.msg import Trajectory
from autoware_system_msgs.msg import AutowareState
from autoware_vehicle_msgs.msg import GearCommand, GearReport
from nav_msgs.msg import Odometry

GEAR = {0: 'NONE', 1: 'NEUTRAL', 2: 'DRIVE', 20: 'REVERSE', 22: 'PARK', 23: 'LOW'}
MODE = {0: 'UNKNOWN', 1: 'STOP', 2: 'AUTONOMOUS', 3: 'LOCAL', 4: 'REMOTE'}
STATE = {1: 'INITIALIZING', 2: 'WAITING_FOR_ROUTE', 3: 'PLANNING', 4: 'WAITING_FOR_ENGAGE',
         5: 'DRIVING', 6: 'ARRIVED_GOAL', 7: 'FINALIZING'}

latched = QoSProfile(depth=1, durability=DurabilityPolicy.TRANSIENT_LOCAL,
                     reliability=ReliabilityPolicy.RELIABLE)


class Probe(Node):
    def __init__(self):
        super().__init__('control_probe')
        self.last = {}
        self.count = {}
        subs = [
            (Control, '/control/trajectory_follower/control_cmd', 10),
            (Control, '/control/command/control_cmd', 10),
            (GearCommand, '/control/command/gear_cmd', 10),
            (GearReport, '/vehicle/status/gear_status', 10),
            (Odometry, '/localization/kinematic_state', 10),
            (Trajectory, '/planning/trajectory', 10),
            (AutowareState, '/autoware/state', 10),
            (OperationModeState, '/api/operation_mode/state', latched),
        ]
        for typ, topic, qos in subs:
            self.create_subscription(typ, topic, lambda m, t=topic: self.on(t, m), qos)

    def on(self, topic, msg):
        self.last[topic] = msg
        self.count[topic] = self.count.get(topic, 0) + 1


def main():
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 5.0
    rclpy.init()
    p = Probe()
    end = time.time() + dur
    while time.time() < end:
        rclpy.spin_once(p, timeout_sec=0.1)
    L, C = p.last, p.count
    print(f'--- {dur:.0f} s; messages received per topic ---')
    for t in sorted(C):
        print(f'  {C[t]:5d}  {t}')
    if '/api/operation_mode/state' in L:
        m = L['/api/operation_mode/state']
        print(f'operation mode: {MODE.get(m.mode, m.mode)}, autonomous available: {m.is_autonomous_mode_available}')
    if '/autoware/state' in L:
        print(f'autoware state: {STATE.get(L["/autoware/state"].state, L["/autoware/state"].state)}')
    for t in ['/control/trajectory_follower/control_cmd', '/control/command/control_cmd']:
        if t in L:
            m = L[t]
            age = time.time() - (m.stamp.sec + m.stamp.nanosec * 1e-9)
            print(f'{t}: vel={m.longitudinal.velocity:.3f} acc={m.longitudinal.acceleration:.3f} '
                  f'steer={m.lateral.steering_tire_angle:.3f} stamp age={age:.2f}s')
        else:
            print(f'{t}: NOT RECEIVED')
    if '/control/command/gear_cmd' in L:
        print(f'gear command: {GEAR.get(L["/control/command/gear_cmd"].command, "?")}')
    if '/vehicle/status/gear_status' in L:
        print(f'gear report:  {GEAR.get(L["/vehicle/status/gear_status"].report, "?")}')
    if '/localization/kinematic_state' in L:
        o = L['/localization/kinematic_state']
        x, y, v = o.pose.pose.position.x, o.pose.pose.position.y, o.twist.twist.linear.x
        print(f'ego: x={x:.2f} y={y:.2f} v={v:.3f}')
        if '/planning/trajectory' in L:
            pts = L['/planning/trajectory'].points
            if pts:
                d = [math.hypot(q.pose.position.x - x, q.pose.position.y - y) for q in pts]
                i = min(range(len(d)), key=d.__getitem__)
                ahead = [q.longitudinal_velocity_mps for q in pts[i:i + 20]]
                print(f'trajectory: {len(pts)} points, closest #{i} at {d[i]:.2f} m, '
                      f'v_closest={pts[i].longitudinal_velocity_mps:.3f}, '
                      f'max v in next 20 points={max(ahead):.3f}')
    p.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
