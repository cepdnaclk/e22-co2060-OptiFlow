import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from route import get_tasks, get_schedule, get_dashboard_stats

def test_schedule_endpoint():
    """Verify get_schedule executes without foreign key ambiguity error."""
    sched = get_schedule()
    assert isinstance(sched, list)

def test_dashboard_stats():
    """Verify get_dashboard_stats executes and returns structure."""
    stats = get_dashboard_stats()
    assert "recent_tasks" in stats
    assert "offline_machines" in stats

def test_marcus_worker_tasks():
    """
    Marcus Johnson (33333333-3333-3333-3333-333333333332)
    mapped to HP Indigo (22222222-2222-2222-2222-222222222222).
    Should return tasks assigned to HP Indigo.
    """
    marcus_id = "33333333-3333-3333-3333-333333333332"
    hp_indigo_id = "22222222-2222-2222-2222-222222222222"
    tasks = get_tasks(marcus_id)
    assert isinstance(tasks, list)
    assert len(tasks) > 0
    for t in tasks:
        assert t["assigned_resource_id"] == hp_indigo_id

def test_elena_worker_tasks():
    """
    Elena Rodriguez (33333333-3333-3333-3333-333333333333)
    mapped to Horizon BQ-470 (22222222-2222-2222-2222-222222222224).
    Should return tasks assigned to Horizon BQ-470.
    """
    elena_id = "33333333-3333-3333-3333-333333333333"
    horizon_id = "22222222-2222-2222-2222-222222222224"
    tasks = get_tasks(elena_id)
    assert isinstance(tasks, list)
    assert len(tasks) > 0
    for t in tasks:
        assert t["assigned_resource_id"] == horizon_id

def test_david_worker_tasks():
    """
    David Kim (33333333-3333-3333-3333-333333333334)
    mapped to Epson SureColor (22222222-2222-2222-2222-222222222225).
    Should return tasks assigned to Epson SureColor.
    """
    david_id = "33333333-3333-3333-3333-333333333334"
    epson_id = "22222222-2222-2222-2222-222222222225"
    tasks = get_tasks(david_id)
    assert isinstance(tasks, list)
    assert len(tasks) > 0
    for t in tasks:
        assert t["assigned_resource_id"] == epson_id

def test_direct_machine_query():
    """
    Direct machine query for HP Indigo (22222222-2222-2222-2222-222222222222).
    Should return tasks assigned to that machine.
    """
    hp_indigo_id = "22222222-2222-2222-2222-222222222222"
    tasks = get_tasks(hp_indigo_id)
    assert isinstance(tasks, list)
    assert len(tasks) > 0
    for t in tasks:
        assert t["assigned_resource_id"] == hp_indigo_id

def test_unassigned_worker():
    """
    Sarah Chen (33333333-3333-3333-3333-333333333331) is a supervisor with no machine assignment.
    Should return empty list [].
    """
    sarah_id = "33333333-3333-3333-3333-333333333331"
    tasks = get_tasks(sarah_id)
    assert isinstance(tasks, list)
    assert len(tasks) == 0

def test_all_tasks_query():
    """
    Querying without resource_id should return all tasks.
    """
    tasks = get_tasks()
    assert isinstance(tasks, list)
    assert len(tasks) >= 4
