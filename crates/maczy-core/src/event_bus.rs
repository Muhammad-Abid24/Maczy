use crate::actions::CommandResult;
use crate::modules::ModuleId;
use crate::state::ModuleRuntimeState;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

/// Events broadcast across application surfaces when state changes occur.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum AppEvent {
    ModuleRuntimeChanged {
        module_id: ModuleId,
        previous: ModuleRuntimeState,
        current: ModuleRuntimeState,
    },
    ActionGated {
        module_id: ModuleId,
        gate_type: String, // "capability" or "permission"
        reason: String,
        error_code: String,
    },
    CommandExecuted {
        module_id: ModuleId,
        result: CommandResult,
    },
}

pub type EventHandler = Arc<dyn Fn(&AppEvent) + Send + Sync + 'static>;

/// Thread-safe event bus distributing state snapshots and transitions across surfaces.
#[derive(Default, Clone)]
pub struct EventBus {
    handlers: Arc<Mutex<Vec<EventHandler>>>,
}

impl EventBus {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn subscribe<F>(&self, handler: F)
    where
        F: Fn(&AppEvent) + Send + Sync + 'static,
    {
        let mut list = self.handlers.lock().unwrap();
        list.push(Arc::new(handler));
    }

    pub fn publish(&self, event: &AppEvent) {
        let list = self.handlers.lock().unwrap();
        for handler in list.iter() {
            handler(event);
        }
    }
}
