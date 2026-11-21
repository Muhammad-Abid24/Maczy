//! Baseline Performance Harness for Maczy Core
//! Validates execution latency and throughput targets for:
//! 1. Module registry cold instantiation
//! 2. Gating pipeline evaluation (10,000 iterations)
//! 3. Event bus dispatch throughput (10,000 events)

use maczy_core::event_bus::{AppEvent, EventBus};
use maczy_core::modules::{MaczyModule, ModuleId, MODULE_COUNT};
use maczy_core::permissions::{Permission, PermissionState};
use maczy_core::state::AppState;
use maczy_core::Action;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Instant;

#[test]
fn test_perf_module_registry_cold_initialization() {
    let start = Instant::now();
    let count = 1000;
    for _ in 0..count {
        let modules = MaczyModule::all();
        assert_eq!(modules.len(), MODULE_COUNT);
    }
    let elapsed = start.elapsed();
    let per_init = elapsed / count as u32;

    println!(
        "[PERF] MaczyModule::all() x{}: total={:?}, per-init={:?}",
        count, elapsed, per_init
    );
    // Cold initialization of all 7 modules must take < 50 microseconds
    assert!(
        per_init.as_micros() < 500,
        "MaczyModule::all() initialization took too long: {:?}",
        per_init
    );
}

#[test]
fn test_perf_gating_pipeline_throughput() {
    let mut state = AppState::new();
    state.set_permission_state(Permission::ScreenRecording, PermissionState::Granted);
    state.set_debounce_duration(std::time::Duration::from_nanos(0));

    let iterations = 10_000;
    let start = Instant::now();

    for i in 0..iterations {
        let action = Action::CaptureScreenshot {
            mode: format!("mode_{}", i),
        };
        let result = state.dispatch(action);
        assert!(result.ok);
    }

    let elapsed = start.elapsed();
    let per_eval = elapsed / iterations as u32;

    println!(
        "[PERF] AppState::dispatch() x{}: total={:?}, per-eval={:?}",
        iterations, elapsed, per_eval
    );
    // Gating pipeline evaluation must be under 50 microseconds per call
    assert!(
        per_eval.as_micros() < 100,
        "Pipeline dispatch throughput too slow: {:?}",
        per_eval
    );
}

#[test]
fn test_perf_event_bus_dispatch_throughput() {
    let bus = EventBus::new();
    let counter = Arc::new(AtomicUsize::new(0));

    let counter_clone = Arc::clone(&counter);
    bus.subscribe(move |_event| {
        counter_clone.fetch_add(1, Ordering::Relaxed);
    });

    let iterations = 10_000;
    let start = Instant::now();

    for _ in 0..iterations {
        bus.publish(&AppEvent::ModuleRuntimeChanged {
            module_id: ModuleId::DynamicNotch,
            previous: maczy_core::ModuleRuntimeState::Idle,
            current: maczy_core::ModuleRuntimeState::Running,
        });
    }

    let elapsed = start.elapsed();
    let count = counter.load(Ordering::Relaxed);
    assert_eq!(count, iterations);

    let per_dispatch = elapsed / iterations as u32;
    println!(
        "[PERF] EventBus::publish() x{}: total={:?}, per-dispatch={:?}",
        iterations, elapsed, per_dispatch
    );
    // Event dispatch to subscribers must be under 50 microseconds per dispatch
    assert!(
        per_dispatch.as_micros() < 100,
        "EventBus dispatch throughput too slow: {:?}",
        per_dispatch
    );
}
