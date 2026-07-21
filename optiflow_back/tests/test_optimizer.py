import unittest
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from pydantic import ValidationError

from main import app, JobOrderInput, SingleJobInput, TaskInput
from models import ResourceCreate, TaskBreakInput
import optimizer

client = TestClient(app)


class TestValidation(unittest.TestCase):

    def test_invalid_priority_rejected(self):
        with self.assertRaises((ValueError, ValidationError)):
            JobOrderInput(title="A", total_quantity=100,
                          deadline=datetime.now().isoformat(),
                          tasks=[], dependencies=[], priority="URGENT")

    def test_valid_priorities_accepted(self):
        for p in ["HIGH", "MEDIUM", "LOW"]:
            obj = JobOrderInput(title="J", total_quantity=1,
                                deadline="2099-01-01T00:00:00Z",
                                tasks=[], dependencies=[], priority=p)
            self.assertEqual(obj.priority, p)

    def test_default_priority_medium(self):
        obj = JobOrderInput(title="J", total_quantity=1,
                            deadline="2099-01-01T00:00:00Z",
                            tasks=[], dependencies=[])
        self.assertEqual(obj.priority, "MEDIUM")

    # --- Test 22: invalid duration validation ---
    def test_invalid_processing_time_rejected(self):
        with self.assertRaises(ValidationError):
            TaskBreakInput(processing_time_minutes=0)
        with self.assertRaises(ValidationError):
            TaskBreakInput(processing_time_minutes=-1)

    def test_valid_processing_time(self):
        t = TaskBreakInput(processing_time_minutes=120)
        self.assertEqual(t.processing_time_minutes, 120)

    # --- Test 23: invalid break-duration validation ---
    def test_break_enabled_zero_duration_rejected(self):
        with self.assertRaises(ValidationError):
            TaskBreakInput(processing_time_minutes=60,
                           break_enabled=True, break_duration_minutes=0)

    def test_break_disabled_forces_zero_duration(self):
        t = TaskBreakInput(processing_time_minutes=60,
                           break_enabled=False, break_duration_minutes=30)
        self.assertEqual(t.break_duration_minutes, 0)

    def test_break_enabled_valid(self):
        t = TaskBreakInput(processing_time_minutes=120,
                           break_enabled=True, break_duration_minutes=5)
        self.assertTrue(t.break_enabled)
        self.assertEqual(t.break_type, "MACHINE")
        self.assertEqual(t.break_duration_minutes, 5)

    def test_break_duration_max_480(self):
        with self.assertRaises(ValidationError):
            TaskBreakInput(processing_time_minutes=60,
                           break_enabled=True, break_duration_minutes=481)

    # --- Test 1: hours * 60 + minutes conversion ---
    def test_two_hours_converts_to_120_minutes(self):
        hours, minutes = 2, 0
        processing_time_minutes = hours * 60 + minutes
        self.assertEqual(processing_time_minutes, 120)
        t = TaskBreakInput(processing_time_minutes=processing_time_minutes)
        self.assertEqual(t.processing_time_minutes, 120)

    # --- resource_level rest removed ---
    def test_resource_create_no_rest_field(self):
        r = ResourceCreate(name="Printer", type="MACHINE", status="ACTIVE")
        self.assertFalse(hasattr(r, 'rest_after_task_minutes'))


class TestStatusTransitions(unittest.TestCase):

    # --- Test 21: invalid status-transition rejection ---
    def test_invalid_status_transition_rejected(self):
        with patch('route.supabase') as mock_sb:
            mock_sb.table().select().eq().execute().data = [
                {"id": "t1", "status": "PENDING", "completed_at": None}
            ]
            response = client.patch("/api/tasks/t1/status", json={"status": "IN_PROGRESS"})
            self.assertEqual(response.status_code, 400)

    # --- Test 20: first completion timestamp preserved ---
    def test_first_completion_timestamp_preserved(self):
        with patch('route.supabase') as mock_sb:
            mock_sb.table().select().eq().execute().data = [
                {"id": "t1", "status": "IN_PROGRESS", "completed_at": None}
            ]
            mock_res = MagicMock()
            mock_res.data = [{"id": "t1", "status": "COMPLETED", "completed_at": "2026-07-20T10:00:00Z"}]
            mock_sb.table().update().eq().execute.return_value = mock_res
            response = client.patch("/api/tasks/t1/status", json={"status": "COMPLETED"})
            self.assertEqual(response.status_code, 200)
            call_args = mock_sb.table().update.call_args[0][0]
            self.assertIn("completed_at", call_args)

            # Second COMPLETED should not overwrite
            mock_sb.table().select().eq().execute().data = [
                {"id": "t1", "status": "COMPLETED", "completed_at": "2026-07-20T10:00:00Z"}
            ]
            response = client.patch("/api/tasks/t1/status", json={"status": "COMPLETED"})
            self.assertEqual(response.status_code, 200)
            call_args = mock_sb.table().update.call_args[0][0]
            self.assertNotIn("completed_at", call_args)


class TestSingleJobOptimizer(unittest.TestCase):

    # --- Test 24: single-job backward compatibility ---
    def test_existing_single_job_endpoint(self):
        now = datetime.now(timezone.utc)
        with patch('optimizer.fetch_optiflow_data') as mock_fetch, \
             patch('optimizer.fetch_already_scheduled_intervals') as mock_iv, \
             patch('optimizer.supabase'):
            mock_fetch.return_value = (
                [{"id": "t1", "operation_type_id": "op1", "name": "Task",
                  "quantity_to_process": 1000, "status": "PENDING",
                  "processing_time_minutes": 60, "break_duration_minutes": 0}],
                [],
                [{"resource_id": "r1", "operation_type_id": "op1",
                  "processing_rate_per_hr": 1000, "setup_time_minutes": 0, "cost_per_hour": 10}]
            )
            mock_iv.return_value = {}
            result = optimizer.run_optimization_engine('jobA', now)
            self.assertEqual(result['status'], 'success')

    # --- Test 2: manual processing duration used by optimizer ---
    def test_manual_duration_used_by_optimizer(self):
        now = datetime.now(timezone.utc)
        with patch('optimizer.fetch_optiflow_data') as mock_fetch, \
             patch('optimizer.fetch_already_scheduled_intervals') as mock_iv, \
             patch('optimizer.supabase'):
            mock_fetch.return_value = (
                [{"id": "t1", "operation_type_id": "op1", "name": "T",
                  "quantity_to_process": 1, "status": "PENDING",
                  "processing_time_minutes": 120, "break_duration_minutes": 0}],
                [],
                [{"resource_id": "r1", "operation_type_id": "op1",
                  "processing_rate_per_hr": 1, "setup_time_minutes": 0, "cost_per_hour": 1}]
            )
            mock_iv.return_value = {}
            result = optimizer.run_optimization_engine('j1', now)
            self.assertEqual(result['status'], 'success')
            self.assertEqual(result['makespan_minutes'], 120)


class TestMultiJobOptimizer(unittest.TestCase):

    def _make_task(self, t_id, job_id, op_id="op1", qty=1000, status="PENDING",
                   manual_dur=None, break_dur=0):
        return {"id": t_id, "job_id": job_id, "operation_type_id": op_id,
                "quantity_to_process": qty, "status": status,
                "processing_time_minutes": manual_dur, "break_duration_minutes": break_dur}

    def _make_cap(self, r_id, op_id="op1", rate=1000, setup=0, cost=10):
        return {"resource_id": r_id, "operation_type_id": op_id,
                "processing_rate_per_hr": rate, "setup_time_minutes": setup, "cost_per_hour": cost}

    def _make_job(self, j_id, priority="MEDIUM", deadline_hours=48, now=None):
        now = now or datetime.now(timezone.utc)
        return {"id": j_id, "priority": priority,
                "deadline": (now + timedelta(hours=deadline_hours)).isoformat()}

    def _make_res(self, r_id, status="ACTIVE"):
        return {"id": r_id, "name": r_id, "type": "MACHINE", "status": status}

    # --- Test 13: multiple jobs compete without overlapping resources ---
    @patch('optimizer.supabase')
    def test_multiple_jobs_competing(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now), self._make_job("j2", now=now)]
        tasks = [self._make_task("t1", "j1"), self._make_task("t2", "j2")]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1', 'j2'], now)
            self.assertEqual(result['status'], 'success')
            self.assertEqual(result['makespan_minutes'], 120)

    # --- Test 3: rate-based fallback for old task (no manual_dur) ---
    @patch('optimizer.supabase')
    def test_rate_based_duration_fallback(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        # No processing_time_minutes -> fallback to rate
        tasks = [self._make_task("t1", "j1", qty=1000, manual_dur=None, break_dur=0)]
        caps = [self._make_cap("r1", rate=1000)]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
            self.assertEqual(result['status'], 'success')
            self.assertEqual(result['makespan_minutes'], 60)

    # --- Test 8: no break -> resource released at processing end ---
    @patch('optimizer.supabase')
    def test_no_break_resource_released_at_processing_end(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [
            self._make_task("t1", "j1", manual_dur=60, break_dur=0),
            self._make_task("t2", "j1", manual_dur=60, break_dur=0),
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            optimizer.run_optimization_engine_multi(['j1'], now)
        # t1 ends at 60, t2 starts at 60 (no extra wait from break)
        end1 = datetime.fromisoformat(updated['t1']['scheduled_end_time'])
        start2 = datetime.fromisoformat(updated['t2']['scheduled_start_time'])
        self.assertLessEqual(end1, start2)
        # With no break, rest_end_time == scheduled_end_time
        self.assertEqual(updated['t1']['scheduled_rest_end_time'],
                         updated['t1']['scheduled_end_time'])

    # --- Test 9: 5-min break blocks resource for 5 extra minutes ---
    @patch('optimizer.supabase')
    def test_task_with_5min_break_blocks_resource(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [
            self._make_task("t1", "j1", manual_dur=60, break_dur=5),
            self._make_task("t2", "j1", manual_dur=60, break_dur=0),
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['status'], 'success')
        # The solver schedules t2 first (0-60), then t1 (60-120 processing).
        # t1's break occupies r1 for 5 extra minutes (until 125).
        # Makespan = max(processing_end) = 120 (not 125, break is post-processing).
        self.assertEqual(result['makespan_minutes'], 120)

    # --- Test 10: another resource unaffected by first resource's break ---
    @patch('optimizer.supabase')
    def test_other_resource_free_during_break(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [
            self._make_task("t1", "j1", op_id="op1", manual_dur=60, break_dur=15),
            self._make_task("t2", "j1", op_id="op2", manual_dur=30, break_dur=0),
        ]
        caps = [
            self._make_cap("r1", op_id="op1"),
            self._make_cap("r2", op_id="op2"),
        ]
        res = [self._make_res("r1"), self._make_res("r2")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['status'], 'success')
        # t2 on r2 can start immediately; makespan should be 60 not 75
        self.assertLessEqual(result['makespan_minutes'], 60)

    # --- Test 11: next task on same resource starts at or after rest-end ---
    @patch('optimizer.supabase')
    def test_next_task_starts_after_rest_end(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [
            self._make_task("t1", "j1", manual_dur=60, break_dur=10),
            self._make_task("t2", "j1", manual_dur=60, break_dur=0),
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            optimizer.run_optimization_engine_multi(['j1'], now)
        # Makespan must be 130: the task with break (10 min) forces 130 total
        # because whichever task goes first, if t1 goes first: 60+10+60=130
        # if t2 goes first: t2(0-60), t1(60-120), t1 rest_end=130, makespan=120
        # Solver minimises makespan so it puts t2 first => makespan=120
        # The key property: the second task's start >= first task's rest_end
        def _parse(s):
            return datetime.fromisoformat(s.replace('Z', '+00:00'))
        t1_start = _parse(updated['t1']['scheduled_start_time'])
        t2_start = _parse(updated['t2']['scheduled_start_time'])
        if t1_start < t2_start:
            # t1 goes first; t2 must start >= t1's rest_end
            t1_rest = _parse(updated['t1']['scheduled_rest_end_time'])
            self.assertGreaterEqual(t2_start, t1_rest)
        else:
            # t2 goes first; t1 must start >= t2's rest_end
            t2_rest = _parse(updated['t2']['scheduled_rest_end_time'])
            self.assertGreaterEqual(t1_start, t2_rest)

    # --- Test 12: dependent task needn't wait for predecessor's machine break ---
    @patch('optimizer.supabase')
    def test_dependent_task_no_forced_break_wait(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        # t1 on r1 with 15min break; t2 on r2 depends on t1 processing end only
        tasks = [
            self._make_task("t1", "j1", op_id="op1", manual_dur=60, break_dur=15),
            self._make_task("t2", "j1", op_id="op2", manual_dur=60, break_dur=0),
        ]
        deps = [{"predecessor_task_id": "t1", "successor_task_id": "t2",
                 "mandatory_wait_minutes": 0}]
        caps = [self._make_cap("r1", op_id="op1"), self._make_cap("r2", op_id="op2")]
        res = [self._make_res("r1"), self._make_res("r2")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, deps, caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['status'], 'success')
        # t2 may start at processing_end(t1)=60, not at rest_end(t1)=75
        start2 = datetime.fromisoformat(updated['t2']['scheduled_start_time'])
        t1_end = datetime.fromisoformat(updated['t1']['scheduled_end_time'])
        self.assertGreaterEqual(start2, t1_end)
        # makespan should be 120 (t1 60, t2 starts at 60 on r2, ends at 120)
        self.assertEqual(result['makespan_minutes'], 120)

    # --- Test 14: priority ordering ---
    @patch('optimizer.supabase')
    def test_priority_ordering(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [
            self._make_job("j_low", priority="LOW", deadline_hours=48, now=now),
            self._make_job("j_high", priority="HIGH", deadline_hours=48, now=now),
        ]
        tasks = [
            self._make_task("t_low", "j_low"),
            self._make_task("t_high", "j_high"),
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        updated = {}
        def mock_update(data):
            class E:
                def eq(self, f, v):
                    updated[v] = data
                    class X:
                        def execute(self): pass
                    return X()
            return E()
        mock_sb.table().update.side_effect = mock_update
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            optimizer.run_optimization_engine_multi(['j_low', 'j_high'], now)
        high_start = datetime.fromisoformat(updated['t_high']['scheduled_start_time'])
        low_start = datetime.fromisoformat(updated['t_low']['scheduled_start_time'])
        self.assertLess(high_start, low_start)

    # --- Test 15: offline resource exclusion ---
    @patch('optimizer.supabase')
    def test_offline_resource_exclusion(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1")]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1", status="OFFLINE")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['status'], 'error')
        self.assertIn("capable active resources", result['message'])

    # --- Test 16: cyclic dependencies ---
    @patch('optimizer.supabase')
    def test_cyclic_dependency(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1"), self._make_task("t2", "j1")]
        deps = [
            {"predecessor_task_id": "t1", "successor_task_id": "t2", "mandatory_wait_minutes": 0},
            {"predecessor_task_id": "t2", "successor_task_id": "t1", "mandatory_wait_minutes": 0},
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, deps, caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['status'], 'error')

    # --- Test 17: mandatory wait time ---
    @patch('optimizer.supabase')
    def test_mandatory_wait_time(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1"), self._make_task("t2", "j1")]
        deps = [{"predecessor_task_id": "t1", "successor_task_id": "t2",
                 "mandatory_wait_minutes": 20}]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, deps, caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['makespan_minutes'], 140)

    # --- Test 18: in-progress fixed intervals ---
    @patch('optimizer.supabase')
    def test_in_progress_task_fixed(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        ip_task = self._make_task("t1", "j1", status="IN_PROGRESS")
        ip_task["scheduled_start_time"] = now.isoformat()
        ip_task["scheduled_end_time"] = (now + timedelta(hours=1)).isoformat()
        tasks = [ip_task, self._make_task("t2", "j1")]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['makespan_minutes'], 60)

    # --- Test 19: completed task preserved ---
    @patch('optimizer.supabase')
    def test_completed_task_unchanged(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [
            self._make_task("t1", "j1", status="COMPLETED"),
            self._make_task("t2", "j1"),
        ]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['makespan_minutes'], 60)

    # --- Test 4: no restriction -> solver picks from capable resources ---
    @patch('optimizer.supabase')
    def test_no_resource_restriction_picks_capable(self, mock_sb):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1", qty=2000, manual_dur=None)]
        caps = [
            self._make_cap("fast", rate=2000),
            self._make_cap("slow", rate=1000),
        ]
        res = [self._make_res("fast"), self._make_res("slow")]
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['makespan_minutes'], 60)

    # --- Lexicographic solver quality tests ---
    @patch('optimizer.cp_model.CpSolver')
    @patch('optimizer.supabase')
    def test_all_passes_optimal(self, mock_sb, mock_solver_cls):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1")]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        mock_inst = MagicMock()
        mock_solver_cls.return_value = mock_inst
        mock_inst.Solve.return_value = optimizer.cp_model.OPTIMAL
        mock_inst.Value.return_value = 100
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['quality'], 'optimal')

    @patch('optimizer.cp_model.CpSolver')
    @patch('optimizer.supabase')
    def test_first_pass_feasible_stops_early(self, mock_sb, mock_solver_cls):
        now = datetime.now(timezone.utc)
        jobs = [self._make_job("j1", now=now)]
        tasks = [self._make_task("t1", "j1")]
        caps = [self._make_cap("r1")]
        res = [self._make_res("r1")]
        mock_inst = MagicMock()
        mock_solver_cls.return_value = mock_inst
        mock_inst.Solve.return_value = optimizer.cp_model.FEASIBLE
        mock_inst.Value.return_value = 100
        with patch('optimizer.fetch_multi_optiflow_data', return_value=(jobs, tasks, [], caps, res)), \
             patch('optimizer.fetch_multi_already_scheduled_intervals', return_value={}):
            result = optimizer.run_optimization_engine_multi(['j1'], now)
        self.assertEqual(result['quality'], 'feasible')
        self.assertEqual(mock_inst.Solve.call_count, 1)


if __name__ == '__main__':
    unittest.main()
