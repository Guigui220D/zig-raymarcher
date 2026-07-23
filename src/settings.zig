// TODO: make this an object and add current_settings and default_settings

pub const DebugMode = enum {
    none,
    material_ids,
    refl_factor,
    dot,
};

pub var hit_distance: f64 = 0.02;
pub var max_steps: usize = 1024;
pub var max_steps_getting_closer: usize = 2048;
pub var max_reflections: usize = 6;
pub var preview: bool = false;
pub var debug_mode: DebugMode = .none;
pub var benchmark: bool = false;
pub var benchmark_it: usize = 5;
